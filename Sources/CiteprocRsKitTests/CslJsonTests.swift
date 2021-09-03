//
//  CslJsonTests.swift
//  CiteprocRsKitTests
//
//  Created by Cormac Relf on 31/8/21.
//

import CiteprocRsKit
import Foundation
import XCTest

@available(macOS 10.15, *)  // .sortedKeys, .withoutEscapingSlashes
final class CslJsonTests: XCTestCase {
    var encoder: JSONEncoder = JSONEncoder()
    override func setUp() {
        // for reliable tests
        encoder.outputFormatting = .prettyPrinted.union(.sortedKeys).union(.withoutEscapingSlashes)
    }

    func testStringVariable() throws {
        let variable: CslVariable = .string("hello")
        let result = try encoder.encode(variable)
        XCTAssertEqual(String(data: result, encoding: .utf8), "\"hello\"")
    }

    func testNameVariable() throws {
        let variable: CslVariable = .names([CslName(family: "Smith", given: "John")])
        let result = try encoder.encode(variable)
        XCTAssertEqual(
            String(data: result, encoding: .utf8)!,
            """
            [
              {
                "family" : "Smith",
                "given" : "John"
              }
            ]
            """)
    }

    func testTitleString() throws {
        let variable: CslVariable = .title(.string("Main Title: Subtitle"))
        let result = try encoder.encode(variable)
        XCTAssertEqual(
            String(data: result, encoding: .utf8)!,
            """
            "Main Title: Subtitle"
            """)
    }

    func testTitles() throws {
        let variable: CslVariable = .title(.object(.init(full: "Main Title: Subtitle")))
        let result = try encoder.encode(variable)
        XCTAssertEqual(
            String(data: result, encoding: .utf8)!,
            """
            {
              "full" : "Main Title: Subtitle"
            }
            """)
    }

    func testDateParts() throws {
        let variable: CslVariable = .date(.v1(.init(dateParts: [[2021, 2, 1]])))
        let result = try encoder.encode(variable)
        XCTAssertEqual(
            String(data: result, encoding: .utf8)!,
            """
            {
              "date-parts" : [
                [
                  2021,
                  2,
                  1
                ]
              ]
            }
            """)
    }

    func testReference() throws {
        let reference: CslReference = CslReference(
            id: "id", type: "book",
            variables: [
                "author": .names([CslName(family: "Smith", given: "John")]),
                "issued": .date(.v1(.init(raw: "2021"))),
                "version": .number(.int(2)),
                "title": .string("Title"),
            ])
        let result = try encoder.encode(reference)
        XCTAssertEqual(
            String(data: result, encoding: .utf8)!,
            """
            {
              "author" : [
                {
                  "family" : "Smith",
                  "given" : "John"
                }
              ],
              "id" : "id",
              "issued" : {
                "raw" : "2021"
              },
              "title" : "Title",
              "type" : "book",
              "version" : 2
            }
            """)
    }

    func testBadVarName() throws {
        let reference: CslReference = CslReference(
            id: "id", type: "book",
            variables: [
                "id": .string("String"),
                "type": .string("String"),
            ])
        let result = try encoder.encode(reference)
        XCTAssertEqual(
            String(data: result, encoding: .utf8)!,
            """
            {
              "id" : "id",
              "type" : "book"
            }
            """)
    }

}
