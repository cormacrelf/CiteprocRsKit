//
//  CiteprocRsKitTests.swift
//  CiteprocRsKitTests
//
//  Created by Cormac Relf on 24/3/21.
//

import XCTest
@testable import CiteprocRsKit

class CiteprocRsKitTests: XCTestCase {

    override func setUpWithError() throws {
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }

    func testExample() throws {
        let EN_US = "<locale version=\"1.0\" xml:lang=\"en-US\">\n<info> <updated>2015-10-10T23:31:02+00:00</updated> </info><terms> </terms></locale>"
        let style = "<style xmlns=\"http://purl.org/net/xbiblio/csl\" class=\"note\" version=\"1.0\" default-locale=\"en-GB\"><info><id>id</id><title>title</title><updated>2015-10-10T23:31:02+00:00</updated></info> <citation><layout><text variable=\"title\" /></layout></citation></style>";
        
        let locale_callback: (String) -> String? = { lang in
            if lang == "en-US" {
                print("returning en-US locale")
                return EN_US
            } else {
                print("I don't know that locale " + lang)
                return nil
            }
        }
        let driver = Driver.new(options: InitOptions(style: style, locale_callback: locale_callback))
        
        XCTAssert(driver != nil)
    }

//    func testPerformanceExample() throws {
//        // This is an example of a performance test case.
//        self.measure {
//            // Put the code you want to measure the time of here.
//        }
//    }

}
