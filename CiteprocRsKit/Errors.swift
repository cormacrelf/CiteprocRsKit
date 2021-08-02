//
//  Errors.swift
//  CiteprocRsKit
//
//  Created by Cormac Relf on 28/7/21.
//

import CiteprocRs
import Foundation

extension CRErrorCode: CustomStringConvertible {
    public var description: String {
        switch self {
        case .bufferOps: return "bufferOps"
        case .caughtPanic: return "caughtPanic"
        case .none: return "none"
        case .nullByte: return "nullByte"
        case .poisoned: return "poisoned"
        case .reordering: return "reordering"
        case .serdeJson: return "serdeJson"
        case .utf8: return "utf8"
        case .nullPointer: return "nullPointer"
        case .indexing: return "indexing"
        case .clusterNotInFlow: return "clusterNotInFlow"
        case .invalidStyle: return "invalidStyle"
        @unknown default: return "unknown(error code \(self.rawValue))"
        }
    }
}

extension CRErrorCode: CustomDebugStringConvertible {
    public var debugDescription: String {
        return "CiteprocRsErrorCode." + self.description
    }
}

public struct CRBindingsError: Error, Equatable {
    public let code: CRErrorCode
    public let message: String

    internal init(_ code: CRErrorCode, _ message: String) {
        self.code = code
        self.message = message
    }
}

extension CRBindingsError {

    private static func with_display_text(code: CRErrorCode) -> CRBindingsError {
        var buffer = UTF8Buffer()
        let write_err_err = Swift.withUnsafeMutablePointer(
            to: &buffer,
            { user_buf in
                CiteprocRs.citeproc_rs_last_error_utf8(buffer_ops: BufferOps, user_data: user_buf)
            })
        if write_err_err != CRErrorCode.none {
            return .init(code, "error message could not be read, reading gave \(write_err_err)")
        }
        let string = buffer.to_string()
        return .init(code, string)
    }

    internal static func from_last_error() -> Self? {
        let code = CiteprocRs.citeproc_rs_last_error_code()
        if code == CRErrorCode.none {
            return nil
        }
        return Self.with_display_text(code: code)
    }

    internal static func last_or_default(default _default: CRBindingsError = CRBindingsError.init(CRErrorCode.none, "unknown error")) -> Self {
        if let err = CRBindingsError.from_last_error() {
            return err
        } else {
            return _default
        }
    }

    internal static func maybe_throw(returned code: CRErrorCode, api_name: String = "")
        throws
    {
        if code == CRErrorCode.none {
            return
        }
        if let err = CRBindingsError.from_last_error() {
            throw err
        }
    }
}
