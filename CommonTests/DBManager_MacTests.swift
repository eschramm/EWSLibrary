//
//  DBManager_MacTests.swift
//  EWSLibrary_Mac
//
//  Created by Eric Schramm on 7/24/18.
//  Copyright © 2018 eware. All rights reserved.
//

import XCTest
@testable import EWSLibrary

class DBManager_MacTests: XCTestCase {
    
    var dbManager: DBManager!
    
    override func setUp() {
        super.setUp()
        dbManager = createManager()
    }
    
    override func tearDown() {
        dbManager.nukeDatabase()
        super.tearDown()
    }
    
    func testDatabaseExists() {
        DBManager_SharedTests.testDatabaseExists(dbManager: dbManager)
    }
    
    func testWriteReadTypes() {
        DBManager_SharedTests.testWriteReadTypes(dbManager: dbManager)
    }
    
    func testDeleteNetworked() {
        DBManager_SharedTests.testDeleteNetworked(dbManager: dbManager)
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
}
