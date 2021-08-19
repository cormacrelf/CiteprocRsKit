//
//  Logger.swift
//  CiteprocRsKit
//
//  Created by Cormac Relf on 9/8/21.
//

import Foundation
import CiteprocRs
import os

/// `.error = 1, .warn, .info, .debug, .trace`: Log severity levels from the Rust [`log` crate](https://lib.rs/crates/log).
public typealias CRLogLevel = CiteprocRs.CRLogLevel
/// `.off, .error, .warn, .info, .debug, .trace`: Log level filters from the Rust [`log` crate](https://lib.rs/crates/log). `.off` means "no logs should be logged"; `.warn` means "errors and warnings should be logged".
public typealias CRLevelFilter = CiteprocRs.CRLevelFilter

func log_backend_write(instance: UnsafeMutableRawPointer?, level: CRLogLevel, modpath: UnsafePointer<UInt8>?, modpath_len: UInt, msg: UnsafePointer<UInt8>?, msg_len: UInt) {
    guard let instance = instance else {
        return
    }
    let receiver: CRLogReceiver = Unmanaged.fromOpaque(instance).takeUnretainedValue()
    let modpath_buf = UnsafeBufferPointer(start: modpath!, count: Int(modpath_len))
    let modpath = String(decoding: modpath_buf, as: UTF8.self)
    let message_buf = UnsafeBufferPointer(start: msg!, count: Int(msg_len))
    let message = String(decoding: message_buf, as: UTF8.self)
    receiver.backend.log(level: level, module_path: modpath, message: message)
}

func log_backend_flush(instance: UnsafeMutableRawPointer?) {
    // noop
}

let vtable: CRFFILoggerVTable = CRFFILoggerVTable(
    write: log_backend_write,
    flush: log_backend_flush
);


///  A logging backend to install globally, that citeproc-rs will use for all its logging. You can only install a logger once.
public struct CRLogger {
    fileprivate init(minSeverity: CRLevelFilter, filter: String = "", backend: CRLog) throws {
        self.minSeverity = minSeverity
        self.filterString = filter
        self.backend = backend
        try self.tryInstall()
    }
    var filterString: String = "";
    let minSeverity: CRLevelFilter;
    let backend: CRLog
    
    //    @available(macOS 11, iOS 14, macCatalyst 14, *)
    //    public init(minSeverity: CRLevelFilter, filter: String = "", osLogger: ()) {
    //        let backend = CROSLoggerNew()
    //        self.init(minSeverity: minSeverity, filter: filter, backend: backend)
    //    }
    
    /// Installs any CRLog-implementing backend to handle log events. Fails if called when a logger is already installed.
    public static func install(minSeverity: CRLevelFilter, filter: String = "", backend: CRLog) throws {
        let _ = try Self.init(minSeverity: minSeverity, filter: filter, backend: backend)
    }
    
    /// Installs a logger compatible with Unified Logging on iOS/macOS. Fails if called when a logger is already installed.
    ///
    /// This logger uses the module path as a unified logging "category", rather than writing it into the message.
    @available(macOS 10.12, iOS 10, macCatalyst 13, *)
    public static func unifiedLogging(minSeverity: CRLevelFilter, filter: String = "") throws {
        let backend = CROSLogger()
        let _ = try Self.init(minSeverity: minSeverity, filter: filter, backend: backend)
    }
    
    func tryInstall() throws {
        let wrapper = CRLogReceiver(backend: self.backend)
        let unbalanced = Unmanaged.passRetained(wrapper).toOpaque()
        let minSev = self.minSeverity
        var filterString = self.filterString
        let code = filterString.withUTF8Rust({ filters, filters_len in
            return citeproc_rs_set_logger(instance: unbalanced, vtable: vtable, min_severity: minSev, filters: filters, filters_len: filters_len);
        })
        try CRError.maybe_throw(returned: code)
    }
}

/// A protocol for logging implementations that can print (or ignore) a a message logged via the Rust [`log` crate](https://lib.rs/crates/log).
///
/// The simplest non-trivial implementation would be to simply `print(level, module_path, message)`.
public protocol CRLog {
    /// In order, these three are ERROR/WARN/etc, then a citeproc_proc::db::... path of where the log was generated, and a message.
    func log(level: CRLogLevel, module_path: String, message: String) -> Void
}

class CRLogReceiver {
    internal init(backend: CRLog) {
        self.backend = backend
    }
    
    var buffer: Data = .init()
    var backend: CRLog
    
    deinit {
        print("should not ever deinit LogBackend. it should have the static lifetime")
    }
}

internal let SUBSYSTEM = "net.cormacrelf.CiteprocRsKit"

// No need. Functionality is covered by the os_log version
//
//@available(macOS 11, iOS 14, macCatalyst 14, *)
//public class CROSLoggerNew: CRLog {
//    var loggers: [String: Logger] = [:]
//    public init() {}
//    public func log(level: CRLogLevel, module_path: String, message: String) {
//        var _logger = self.loggers[module_path]
//        if _logger == nil {
//            _logger = Logger(subsystem: SUBSYSTEM, category: module_path)
//            self.loggers[module_path] = _logger;
//        }
//        let logger = _logger!
//
//        logger.log(level: level.osLogType(), "[\(level)] \(message)")
//    }
//}

/// A logger that uses the Unified Logging system introduced in 2016.
@available(macOS 10.12, iOS 10, macCatalyst 13, *)
public class CROSLogger: CRLog {
    public init() {}
    public func log(level: CRLogLevel, module_path: String, message: String) {
        let logger = OSLog(subsystem: SUBSYSTEM, category: module_path)
        os_log("[%{public}@] %{public}@", log: logger, type: level.osLogType(), level.description, message)
    }
}

extension CRLogLevel {
    /// A reasonable conversion from the Rust `log` crate's level to `os.OSLogType` levels.
    public func osLogType() -> OSLogType {
        switch self {
        case .trace: fallthrough
        case .debug: return .debug
        case .info: return .info
        case .warn: return .default
        case .error: return .error
        @unknown default: return .default
        }
    }
}

extension CRLogLevel: Equatable, Comparable, CustomStringConvertible, CustomDebugStringConvertible {
    public static func < (lhs: CRLogLevel, rhs: CRLogLevel) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
    
    public var description: String {
        switch self {
        case .error: return "ERROR"
        case .warn: return "WARN"
        case .info: return "INFO"
        case .debug: return "DEBUG"
        case .trace: return "TRACE"
        @unknown default: return "unknown log level \(self.rawValue)"
        }
    }
    
    public var debugDescription: String {
        return self.description
    }
}

extension CRLevelFilter: Equatable, Comparable, CustomStringConvertible, CustomDebugStringConvertible {
    public static func < (lhs: CRLevelFilter, rhs: CRLevelFilter) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
    
    public var description: String {
        switch self {
        case .off: return "off"
        case .error: return "error"
        case .warn: return "warn"
        case .info: return "info"
        case .debug: return "debug"
        case .trace: return "trace"
        @unknown default: return "unknown CRLevelFilter: \(self.rawValue)"
        }
    }
    
    public var debugDescription: String {
        return "CRLevelFilter." + self.description
    }
}
