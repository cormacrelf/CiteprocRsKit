//
//  PanicTests.swift
//  CiteprocRsKitTests
//
//  Created by Cormac Relf on 2/8/21.
//

import Foundation
import XCTest

@testable import CiteprocRsKit
import CiteprocRs

public func testPanic() throws -> () {
    let code = CiteprocRs.test_panic()
    try CRBindingsError.maybe_throw(returned: code) 
}

public func testDriverPanic(_ driver: CRDriver) throws -> () {
    let raw = driver.raw
    let code = CiteprocRs.test_panic_poison(driver: raw)
    try CRBindingsError.maybe_throw(returned: code)
}

class PanicTests: XCTestCase {
    func testCatchesPanic() throws {
        citeproc_rs_log_init()
        do {
            try testPanic()
            XCTFail("should have thrown when the inner function panicked")
        } catch let e as CRBindingsError {
            XCTAssert(e.code == .caughtPanic)
            print(e.message)
        }
    }
    
    func testPoisoning() throws {
        citeproc_rs_log_init()
        var driver = try CiteprocRsKit.CRDriver.init(style: mkstyle())
        do {
            try testDriverPanic(driver)
            XCTFail("should have thrown when the inner function panicked")
        } catch let e as CRBindingsError {
            XCTAssert(e.code == .caughtPanic)
            print(e.message)
        }
        // now attempt to use it, and fail
        do {
            let _ = try driver.formatBibliography()
            XCTFail("should have thrown when the usage panicked")
        } catch let e as CRBindingsError {
            XCTAssert(e.code == .poisoned)
            print(e.message)
        }
        
        // replace it with a new driver
        driver = try CiteprocRsKit.CRDriver.init(style: mkstyle())
        
        
    }
}
