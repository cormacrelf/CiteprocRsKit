//
//  CiteprocRsKitTests.swift
//  CiteprocRsKitTests
//
//  Created by Cormac Relf on 24/3/21.
//

import XCTest
@testable import CiteprocRsKit

let EN_GB = mklocale(lang: "en-GB")
let style = mkstyle(default_locale: "en-GB");
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
    """;
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
    """;
}

let locale_callback: (String) -> String? = { lang in
    if lang == "en-GB" {
        // print("returning en-GB locale")
        return EN_GB
    } else {
        print("I don't know that locale " + lang)
        return nil
    }
}

let OPTIONS = InitOptions(style: style, locale_callback: locale_callback)

class CiteprocRsKitTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testInit() throws {
        // Let's force it to deinit just so we know
        var d: CiteprocRsDriver? = try CiteprocRsDriver(OPTIONS)
        XCTAssert(d != nil)
        d = nil
    }
    
    func testLocaleFetch() throws {
        let style = mkstyle(default_locale: "de-AT")
        var langs: [String] = []
        let _ = try CiteprocRsDriver(InitOptions(style: style, locale_callback: { lang in
            langs.append(lang)
            return nil
        }))
        langs.sort()
        XCTAssertEqual(langs, ["de-AT", "de-DE"])
    }
    
    func testOne() throws {
        let driver = try CiteprocRsDriver(OPTIONS)
        let empty = try driver.one_ref_citation(["id": "refid", "type": "book"])
        XCTAssertEqual(empty, "[CSL STYLE ERROR: reference with no printed form.]")
        let title = try driver.one_ref_citation(["id": "refid", "type": "book", "title": "the title"])
        XCTAssertEqual(title, "the title")
    }
    
    func testUsesLocale() throws {
        let style = mkstyle(default_locale: "en-GB", citation: mkcitation("""
            <text term="forthcoming" />
        """))
        let chaps = "one moment chaps"
        let driver = try CiteprocRsDriver(InitOptions(style: style, locale_callback: { lang in
            return mklocale(lang: "en-GB", terms: """
                <term name="forthcoming">\(chaps)</term>
            """)
        }))
        let output = try driver.one_ref_citation(["id": "refid", "type": "book"])
        XCTAssertEqual(output, "One moment chaps")
    }
    
    func testAppliesOutputFormat() throws {
        let style = mkstyle(default_locale: "en-GB", citation: mkcitation("""
            <text font-style="italic" value="text" />
        """))
        let tstdriver: (OutputFormat, String) throws -> () = { fmt, res in
            let options = InitOptions(style: style, locale_callback: { mklocale(lang: $0) }, output_format: fmt)
            let d = try CiteprocRsDriver(options)
            let out = try d.one_ref_citation(["id": "refid", "type": "book"])
            XCTAssertEqual(out, res)
        }
        let thrower = {
            throw BindingsError.invalidUtf8
        }
        do {
            try thrower()
        } catch let e as BindingsError {
            print(e)
        }
        try tstdriver(.html, "<i>text</i>")
        try tstdriver(.rtf, "{\\i text}")
        try tstdriver(.plain, "text")
    }

}
