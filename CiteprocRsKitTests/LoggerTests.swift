//
//  LoggerTests.swift
//  CiteprocRsKitTests
//
//  Created by Cormac Relf on 9/8/21.
//

import Foundation
import XCTest
import os

@testable import CiteprocRsKit
@testable import CiteprocRs

class ClosureBackend: CRLog {
    internal init() {
        self.closure = nil
    }
    
    var closure: Optional<(_: CRLogLevel, _: String, _: String) -> Void>;
    
    func log(level: CRLogLevel, module_path: String, message: String) {
        if let c = self.closure {
            c(level, module_path, message)
        }
    }
}

let testBackend = ClosureBackend()

func invokeLog(_ level: CRLogLevel, _ message: String) {
    var string = message
    string.withUTF8Rust { m, m_len in
        test_log_msg(level: level, msg: m, msg_len: m_len)
    }
}

private func assertLog(actual: [(CRLogLevel, String, String)], expected: [(CRLogLevel, String, String)], file: StaticString = #file, line: UInt = #line) {
    if actual.elementsEqual(expected, by: ==) {
    } else {
        XCTFail("Expected \(expected) but was \(actual)", file: file, line: line)
    }
}

// Can't have these running all the time, because setting the logger can be done only once per execution
// and we have more than one test

let enable = false

class LoggerTests: XCTestCase {

    func testAppendLog() throws {
        try XCTSkipUnless(enable)
        try CRLogger.install(minSeverity: CRLevelFilter.warn, filter: "citeproc_rs::logger=error", backend: testBackend)
        
        var saw: [(CRLogLevel, String, String)] = []
        testBackend.closure = { level, module_path, message in
            saw.append((level, module_path, message))
        }
        invokeLog(.warn, "warn only")
        invokeLog(.debug, "debug only")
        invokeLog(.error, "error should show up")
        assertLog(actual: saw, expected: [
            (.error, "citeproc_rs::logger", "error should show up")
        ]);
    }
    
    func testAppendLog2() throws {
        try XCTSkipUnless(enable)
        try CRLogger.install(minSeverity: CRLevelFilter.warn, filter: "", backend: testBackend)
        
        var saw: [(CRLogLevel, String, String)] = []
        testBackend.closure = { level, module_path, message in
            saw.append((level, module_path, message))
        }
        invokeLog(.warn, "warn only")
        invokeLog(.debug, "debug only")
        invokeLog(.error, "error should show up")
        assertLog(actual: saw, expected: [
            (.warn, "citeproc_rs::logger", "warn only"),
            (.error, "citeproc_rs::logger", "error should show up")
        ]);
    }
    
    @available(macOS 10.12, iOS 10, macCatalyst 13, *)
    func testOSLogLegacy() throws {
        try XCTSkipUnless(enable)
        try CRLogger.unifiedLogging(minSeverity: CRLevelFilter.warn, filter: "citeproc_proc::db=debug")
        invokeLog(.debug, "hello from rust log")
        invokeLog(.error, "erro from rust log")
    }
}
