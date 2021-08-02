//
//  ClusterTests.swift
//  CiteprocRsKitTests
//
//  Created by Cormac Relf on 2/8/21.
//

import Foundation

import Foundation
import XCTest
import CiteprocRsKit

let style_bibliography  = """
    <bibliography>
        <layout>
            <group delimiter=", ">
                <names variable="author" />
                <text variable = "title" font-style="italic" />
            </group>
        </layout>
    </bibliography>
"""

class ClusterTests: XCTestCase {
    var driver: CRDriver? = nil

    override func setUpWithError() throws {
        self.driver = try CRDriver.init(style: mkstyle(bibliography: style_bibliography))
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testCreate() throws {
        let driver = self.driver!
        try driver.insertReference(["id": "ref-1", "type": "book", "title": "Sparrows"])
        let cluster = try driver.newCluster("cluster-1")
        let cite = try cluster.newCite(refId: "ref-1")
        try cite.setPrefix("prefix: ")
        let id = try driver.insertCluster(cluster);
        try driver.setClusterOrder(positions: [CRClusterPosition.init(id: id, is_note: true, note_number: 1)])
        let formatted = try driver.formatCluster(clusterId: id)
        XCTAssertEqual(formatted, "prefix: Sparrows")
    }
    
    func testFormatBibliography() throws {
        let driver = self.driver!
        var document: [CRClusterPosition] = []
        var refids: [String] = []
        let references = [
            ["id": "ref-1", "type": "book", "title": "A Flight of Sparrows", "author": [["given": "John", "family": "Smith"]] ],
            ["id": "ref-2", "type": "book", "title": "Seminal works, and how to write them", "author": [["given": "John", "family": "Smith"]]]
        ]
        for refr in references {
            try driver.insertReference(refr)
            refids.append(refr["id"]! as! String)
        }
        var nextClusterId = 1
        let cluster = try driver.newCluster(CRClusterId(nextClusterId))
        for refid in refids {
            let id = CRClusterId(nextClusterId)
            nextClusterId += 1
            try cluster.reset(newId: id)
            let _ = try cluster.newCite(refId: refid)
            let _ = try driver.insertCluster(cluster)
            document.append(CRClusterPosition.init(id: id, is_note: false, note_number: 0))
        }
        
        try driver.setClusterOrder(positions: document)
        let biblio = try driver.formatBibliography()
        XCTAssertEqual(biblio, """
        John Smith, <i>A Flight of Sparrows</i>
        John Smith, <i>Seminal works, and how to write them</i>
        
        """)
    }
}
