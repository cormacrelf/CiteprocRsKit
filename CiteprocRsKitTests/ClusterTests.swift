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
        var document: [CRClusterPosition] = []
        let cluster = try driver.clusterHandle("cluster-1")
        try cluster.appendCite(CRCite(refId: "ref-1", prefix: "prefix: ", suffix: " :suffix", locator: ("56", .chapter)))
        try driver.insertCluster(cluster)
        document.append(.init(id: cluster.id, noteNumber: 1))
        try driver.setClusterOrder(positions: document)
        var formatted = try driver.formatCluster(clusterId: cluster.id)
        XCTAssertEqual(formatted, "prefix: Sparrows, chap. 56 :suffix")
        
        try cluster.reset("cluster-2")
        try cluster.appendCite(refId: "nonexistent")
        try driver.insertCluster(cluster)
        document.append(.init(id: cluster.id, noteNumber: 1))
        try driver.setClusterOrder(positions: document)
        formatted = try driver.formatCluster(clusterId: cluster.id)
        XCTAssertEqual(formatted, "???")
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
        let cluster = try driver.clusterHandle(0)
        for refid in refids {
            try cluster.reset(newId: nextClusterId)
            let _ = try cluster.appendCite(refId: refid)
            try cluster.appendCite(CRCite(refId: "ref-2", prefix: "{, and also}"))
            try driver.insertCluster(cluster)
            document.append(CRClusterPosition(id: nextClusterId, noteNumber: nil))
            nextClusterId += 1
        }
        
        try driver.setClusterOrder(positions: document)
        print(try driver.formatCluster(clusterId: cluster.id))
        let biblio = try driver.formatBibliography()
        XCTAssertEqual(biblio, """
        John Smith, <i>A Flight of Sparrows</i>
        John Smith, <i>Seminal works, and how to write them</i>
        
        """)
    }
    
    func testResetHandleString() throws {
        var driver = Optional(try defaultDriver())
        let handle = try driver?.clusterHandle(0)
        driver = nil
        do {
            try handle!.reset("hello")
            XCTFail("should not reach; ")
        } catch {
            // done
        }
    }
}
