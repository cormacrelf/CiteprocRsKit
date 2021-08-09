//
//  MemoryTests.swift
//  CiteprocRsKitTests
//
//  Created by Cormac Relf on 30/7/21.
//

import Foundation
import XCTest

@testable import CiteprocRsKit

class Signal {
    var notified = false
    func notify() { self.notified = true }
}

class DropCk {
    internal weak var signal: Signal?
    internal var other: Int = 5
    init(signal: Signal) {
        self.signal = signal
    }
    func testAccess() -> Int {
        self.other += 5
        return self.other
    }
    deinit {
        signal?.notify()
    }
}

class MemoryTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testDeinit() throws {
        // Let's force it to deinit just so we know
        var d: CRDriver? = Optional(try defaultDriver())
        XCTAssert(d != nil)
        d = nil
    }

    func testUserDataWhenRetained() throws {
        let signal = Signal()
        var ud = Optional(FFIUserData(DropCk(signal: signal)))
        XCTAssertFalse(signal.notified)
        let raw = ud!.borrow()
        XCTAssertFalse(signal.notified)
        var reconstructed = Optional(FFIUserData<DropCk>.reconstruct(raw))
        XCTAssertFalse(signal.notified)
        // now test access to reconstructed (a shoddy attempt at producing EXC_BAD_ACCESS if not working)
        let _ = reconstructed!.inner.testAccess()
        XCTAssertFalse(signal.notified)
        ud = nil
        XCTAssertFalse(signal.notified)
        reconstructed = nil
        // finally it will die
        XCTAssertTrue(signal.notified)
    }

    func testUserDataManyReconstructions() throws {
        let signal = Signal()
        var ud = Optional(FFIUserData(DropCk(signal: signal)))
        XCTAssertFalse(signal.notified)
        let raw = ud!.borrow()
        XCTAssertFalse(signal.notified)
        for _ in 1...100 {
            let _ = FFIUserData<DropCk>.reconstruct(raw)
            XCTAssertFalse(signal.notified)
        }
        ud = nil
        XCTAssertTrue(signal.notified)
    }

    func testUserDataDeinit() throws {
        let signal = Signal()
        var ud = Optional(FFIUserData(DropCk(signal: signal)))
        let _ = ud?.borrow()

        // ud is still alive.
        XCTAssertFalse(signal.notified)
        // now we release our own hold on ud.
        ud = nil
        // this shows that deinit was called and therefore reconstructing will produce
        // a use-after-free
        XCTAssertTrue(signal.notified)
        // danger!! we deallocated this userdata instance! do not call!
        // let reconstructed = FFIUserData<DropCk>.reconstruct(raw!)
    }

}
