//
//  CiteprocRsKitTests.swift
//  CiteprocRsKitTests
//
//  Created by Cormac Relf on 24/3/21.
//

// @testable makes internal-only things visible to the test module.
// We actually want to know which things are public, such that
// this test suite is somewhat end-to-end.
// @testable
import CiteprocRsKit
import XCTest

let EN_GB = mklocale(lang: "en-GB")
let defaultStyle = mkstyle(default_locale: "en-GB")
func mklocale(lang: String, terms: String = "") -> String {
    return """
        <locale
            version="1.0"
            xml:lang="\(lang)">
            <info>
                <updated>2015-10-10T23:31:02+00:00</updated>
            </info>
            <terms>\(terms)</terms>
        </locale>
        """
}
func mkcitation(_ layout_inner: String = "") -> String {
    return """
        <citation><layout>\(layout_inner)</layout></citation>
        """
}

func mkstyle(
    default_locale: String = "en-GB",
    style_class: String = "note",
    macros: String = "",
    citation: String = "<citation><layout><text variable=\"title\" /></layout></citation>",
    bibliography: String = ""
) -> String {
    return """
        <style xmlns="http://purl.org/net/xbiblio/csl"
        class="\(style_class)"
        version="1.0"
        default-locale="\(default_locale)">
            <info>
                <id>id</id>
                <title>title</title>
                <updated>2015-10-10T23:31:02+00:00</updated>
            </info>
            \(macros)
            \(citation)
            \(bibliography)
        </style>
        """
}

let defaultLocaleCallback: (String) -> String? = { lang in
    if lang == "en-GB" {
        // print("returning en-GB locale")
        return EN_GB
    } else {
        print("I don't know that locale " + lang)
        return nil
    }
}

func defaultDriver() throws -> CRDriver {
    return try CRDriver(style: defaultStyle, localeCallback: defaultLocaleCallback)
}

class CiteprocRsKitTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testInit() throws {
        // Let's force it to deinit just so we know
        var d: CRDriver? = try defaultDriver()
        XCTAssert(d != nil)
        d = nil
    }
    
    func testInvalidStyle() throws {
        var error: String? = nil
        do {
            let _ = try CRDriver(style: mkstyle(citation: ""), localeCallback: { _ in nil }, outputFormat: .html)
        } catch let e as CRBindingsError {
            switch e.code {
            case .invalidStyle: error = e.message; break
            default: XCTFail("wrong error code, expected invalidStyle, got \(e)")
            }
        }
        XCTAssert(error != nil)
        XCTAssert(error == "style error: invalid style: bytes 0..246 [Error] Must have exactly one <citation> ()\n")
    }

    func testLocaleFetch() throws {
        let style = mkstyle(default_locale: "de-AT")
        var langs: [String] = []
        let _ = try CRDriver(
                style: style,
                localeCallback: { lang in
                    langs.append(lang)
                    return nil
                })
        langs.sort()
        XCTAssertEqual(langs, ["de-AT", "de-DE"])
    }

    func testOne() throws {
        let driver = try defaultDriver()
        let empty = try driver.previewReference(["id": "refid", "type": "book"])
        XCTAssertEqual(empty, "[CSL STYLE ERROR: reference with no printed form.]")
        let title = try driver.previewReference([
            "id": "refid", "type": "book", "title": "the title",
        ])
        XCTAssertEqual(title, "the title")
    }

    func testUsesLocale() throws {
        let style = mkstyle(
            default_locale: "en-GB",
            citation: mkcitation(
                """
                    <text term="forthcoming" />
                """))
        let chaps = "one moment chaps"
        let driver = try CRDriver(
                style: style,
                localeCallback: { lang in
                    return mklocale(
                        lang: "en-GB",
                        terms: """
                                <term name="forthcoming">\(chaps)</term>
                            """)
                })
        let output = try driver.previewReference(["id": "refid", "type": "book"])
        XCTAssertEqual(output, "One moment chaps")
    }

    func testAppliesOutputFormat() throws {
        let style = mkstyle(
            default_locale: "en-GB",
            citation: mkcitation(
                """
                    <text font-style="italic" value="text" />
                """))
        let tstdriver: (CROutputFormat, String) throws -> Void = { fmt, res in
            let d = try CRDriver(style: style, localeCallback: { mklocale(lang: $0) }, outputFormat: fmt)
            let out = try d.previewReference(["id": "refid", "type": "book"])
            XCTAssertEqual(out, res)
        }
        try tstdriver(.html, "<i>text</i>")
        try tstdriver(.rtf, "{\\i text}")
        try tstdriver(.plain, "text")
    }

    func testInsertReference() throws {
        let driver = try defaultDriver()
        try driver.insertReference(["id": "refid", "type": "book", "title": "The title is here"])
        do {
            // missing required id field
            try driver.insertReference([:])
        } catch let e as CRBindingsError {
            print(e)
            XCTAssertEqual(e.code, CRErrorCode.serdeJson)
        }
    }

}
