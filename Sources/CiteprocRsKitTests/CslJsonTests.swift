//
//  CslJsonTests.swift
//  CiteprocRsKitTests
//
//  Created by Cormac Relf on 31/8/21.
//

import Foundation
import XCTest
import CiteprocRsKit

@available(macOS 10.13, *) // .sortedKeys
final class CslJsonTests: XCTestCase {
    var encoder: JSONEncoder = JSONEncoder()
    override func setUp() {
        // for reliable tests
        encoder.outputFormatting = .sortedKeys
    }
    func testStringVariable() throws {
        let variable: CslVariable = .string("hello");
        let result = try encoder.encode(variable)
        XCTAssertEqual(String(data: result, encoding: .utf8), "\"hello\"")
    }
    func testNameVariable() throws {
        let variable: CslVariable = .names([CslName(family: "Smith", given: "John")]);
        let result = try encoder.encode(variable)
        XCTAssertEqual(String(data: result, encoding: .utf8), """
            [{"family":"Smith","given":"John"}]
            """)
    }
    
    func testTitles() throws {
        let variable: CslVariable = .title(.object(.init(full: "Main Title: Subtitle")))
        let result = try encoder.encode(variable)
        XCTAssertEqual(String(data: result, encoding: .utf8), """
            {"full":"Main Title: Subtitle"}
            """)
    }

    func testReference() throws {
        let reference: CslReference = CslReference(id: "id", type: "book", variables: [
            "author": .names([CslName(family: "Smith", given: "John")]),
            "issued": .date(.edtf("2021")),
            "version": .number(.int(2)),
            "title": .string("Title"),
        ])
        let result = try encoder.encode(reference)
        XCTAssertEqual(String(data: result, encoding: .utf8), """
            {"author":[{"family":"Smith","given":"John"}],"id":"id","issued":"2021","title":"Title","type":"book","version":2}
            """)
    }
    
    
}
