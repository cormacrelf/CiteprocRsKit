//
//  PanicTests.swift
//  CiteprocRsKitTests
//
//  Created by Cormac Relf on 2/8/21.
//

import Foundation
import XCTest

@testable import CiteprocRsKit
@testable import CiteprocRs

public func testPanic() throws -> () {
    let code = CiteprocRs.test_panic()
    try CRError.maybe_throw(returned: code)
}

public func testDriverPanic(_ driver: CRDriver) throws -> () {
    let raw = driver.raw
    let code = CiteprocRs.test_panic_poison_driver(_driver: raw)
    try CRError.maybe_throw(returned: code)
}

class PanicTests: XCTestCase {
    override func setUp() {
        citeproc_rs_log_init()
    }
    func testCatchesPanic() throws {
        do {
            try testPanic()
            XCTFail("should have thrown when the inner function panicked")
        } catch let e as CRError {
            XCTAssert(e.code == .caughtPanic)
            // print(e.message)
        }
    }
    
    func testPoisoning() throws {
        var driver = try CRDriver(style: mkstyle())
        do {
            try testDriverPanic(driver)
            XCTFail("should have thrown when the inner function panicked")
        } catch let e as CRError {
            XCTAssert(e.code == .caughtPanic)
            // print("caught error with message:", e.message)
        }
        // now attempt to use it, and fail
        do {
            let _ = try driver.formatBibliography()
            XCTFail("should have thrown when the usage panicked")
        } catch let e as CRError {
            XCTAssert(e.code == .poisoned)
            // print("caught error with message:", e.message)
        }
        
        // replace it with a new driver
        driver = try CRDriver(style: mkstyle())
        // the new one works
        let _ = try driver.formatBibliography()
    }
}
