//
//  DBManager_MacTests.swift
//  EWSLibrary_Mac
//
//  Created by Eric Schramm on 7/24/18.
//  Copyright © 2018 eware. All rights reserved.
//

import XCTest
@testable import EWSLibrary

struct Person: DBModel {
    
    static let firstNameField = DBField(keyName: "firstName", dbFieldName: nil, dataType: .text, constraints: [.notNull])
    static let lastNameField = DBField(keyName: "lastName", dbFieldName: nil, dataType: .text, constraints: [.notNull])
    static let weightField = DBField(keyName: "weight", dbFieldName: "WeightMotherFucker", dataType: .real, constraints: [.notNull])
    static let timeStampField = DBField(keyName: "timeStamp", dbFieldName: nil, dataType: .dateTime, constraints: [.notNull])
    
    static var table: DBTable {
        return DBTable(keyName: "Person", dbTableName: "People", indexes: [DBIndex(name: "idx_last_first", fields: [lastNameField, firstNameField], unique: true)])
    }
    
    static var fields: [DBField] {
        return [
            firstNameField,
            lastNameField,
            weightField,
            timeStampField
        ]
    }
    
    var dataDictionary: [String : Any] {
        return [
            "zID" : zID ?? NSNull(),
            "firstName" : firstName,
            "lastName" : lastName,
            "weight" : weight,
            "timeStamp" : timeStamp
        ]
    }
    
    let zID: RecordID?
    let firstName: String
    let lastName: String
    let weight: Double
    let timeStamp: Date
    
    init?(dataDictionary: [String : Any]) {
        if let firstName = dataDictionary["firstName"] as? String,
            let lastName = dataDictionary["lastName"] as? String,
            let weight = dataDictionary["weight"] as? Double,
            let timeStamp = dataDictionary["timeStamp"] as? Date
        {
            self.firstName = firstName
            self.lastName = lastName
            self.zID = dataDictionary["zID"] as? RecordID
            self.weight = weight
            self.timeStamp = timeStamp
        } else {
            return nil
        }
    }
    
    init(firstName: String, lastName: String, weight: Double, timeStamp: Date) {
        self.firstName = firstName
        self.lastName = lastName
        self.zID = nil
        self.weight = weight
        self.timeStamp = timeStamp
    }
}

class DBManager_MacTests: XCTestCase {
    
    var manager: DBManager!
    
    override func setUp() {
        super.setUp()
        manager = DBManager(filePath: "/Users/ericschramm/Dropbox/Apps/Testing/TestDB.sqlite", models: [Person.self])
        manager.createDatabaseIfNotExist()
    }
    
    override func tearDown() {
        manager.nukeDatabase()
        super.tearDown()
    }
    
    func testExample() {
        let person = Person(firstName: "Eric", lastName: "Schramm", weight: 123.456, timeStamp: Date())
        let person2 = Person(firstName: "Jennifer", lastName: "Schramm", weight: 234.567, timeStamp: Date().addingTimeInterval(60 * 60 * 24 * -2))
        let savedResult : Result<Person> = person.save(dbManager: manager)
        print(savedResult)
        let savedResult2 : Result<Person> = person2.save(dbManager: manager)
        print(savedResult2)
    }
    
    func testPerformanceExample() {
        // This is an example of a performance test case.
        self.measure {
            // Put the code you want to measure the time of here.
        }
    }
    
}
