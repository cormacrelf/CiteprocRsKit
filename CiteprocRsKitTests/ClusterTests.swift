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

class ClusterTests: XCTestCase {
    var driver: CRDriver? = nil

    override func setUpWithError() throws {
        try setUpLogging()
        self.driver = try CRDriver(style: mkstyle(citation: mkcitation("""
            <group delimiter=", ">
                <text variable="title" />
                <group delimiter=" ">
                    <label variable="locator" form="short" />
                    <text variable="locator" />
                </group>
            </group>
            """), bibliography: mkbibliography("""
            <group delimiter=", ">
                <names variable="author" />
                <text variable = "title" font-style="italic" />
            </group>
            """)
        ))
        
    }

    override func tearDownWithError() throws {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
    }
    
    func testCreate() throws {
        let driver = self.driver!
        try driver.insertReference(["id": "ref-1", "type": "book", "title": "Sparrows"])
        let cluster = try driver.clusterHandle("cluster-1")
        let cite = try cluster.newCite(refId: "nonexistent-ref")
        try cite.setPrefix("prefix: ")
        try cite.setSuffix(" :suffix")
        try cite.setRefId("ref-1")
        try cite.setLocator("56", locType: .page)
        let id = try driver.insertCluster(cluster);
        try driver.setClusterOrder(positions: [CRClusterPosition(id: id, noteNumber: 1)])
        let formatted = try driver.formatCluster(clusterId: id)
        XCTAssertEqual(formatted, "prefix: Sparrows, p. 56 :suffix")
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
        
        var nextClusterId = CRClusterId(0) // we'll reset the handle before we use the zero id
        let cluster = try driver.clusterHandle(nextClusterId)
        for refid in refids {
            try cluster.reset(newId: nextClusterId)
            let _ = try cluster.newCite(refId: refid)
            let _ = try driver.insertCluster(cluster)
            document.append(CRClusterPosition(id: nextClusterId, noteNumber: nil))
            nextClusterId += 1
        }
        
        try driver.setClusterOrder(positions: document)
        let biblio = try driver.formatBibliography()
        XCTAssertEqual(biblio, """
        John Smith, <i>A Flight of Sparrows</i>
        John Smith, <i>Seminal works, and how to write them</i>
        
        """)
    }
}
