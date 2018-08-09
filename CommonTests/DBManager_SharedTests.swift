//
//  DBManager_SharedTests.swift
//  EWSLibrary_iOS
//
//  Created by Eric Schramm on 7/25/18.
//  Copyright © 2018 eware. All rights reserved.
//

import XCTest
@testable import EWSLibrary

struct Person: DBModel {
    
    static let firstNameField = DBField(keyName: "firstName", dbFieldName: nil, dataType: .text, constraints: [.notNull])
    static let lastNameField = DBField(keyName: "lastName", dbFieldName: nil, dataType: .text, constraints: [.notNull])
    static let weightField = DBField(keyName: "weight", dbFieldName: "WeightMotherFucker", dataType: .real, constraints: [.notNull])
    static let ageField = DBField(keyName: "age", dbFieldName: nil, dataType: .integer, constraints: [.notNull])
    static let timeStampField = DBField(keyName: "timeStamp", dbFieldName: nil, dataType: .dateTime, constraints: [.notNull])
    
    static var table: DBTable {
        return DBTable(keyName: "Person", dbTableName: "People", indexes: [DBIndex(name: "idx_last_first", fields: [lastNameField, firstNameField], unique: true)])
    }
    
    static var fields: [DBField] {
        return [
            firstNameField,
            lastNameField,
            weightField,
            ageField,
            timeStampField
        ]
    }
    
    var dataDictionary: [String : Any] {
        return [
            "zID" : zID ?? NSNull(),
            "firstName" : firstName,
            "lastName" : lastName,
            "weight" : weight,
            "age" : age,
            "timeStamp" : timeStamp
        ]
    }
    
    static let zIDfieldOverride: String? = nil
    
    let zID: RecordID?
    let firstName: String
    let lastName: String
    let weight: Double
    let age: Int32
    let timeStamp: Date
    
    init?(dataDictionary: [String : Any]) {
        if let firstName = dataDictionary["firstName"] as? String,
            let lastName = dataDictionary["lastName"] as? String,
            let weight = dataDictionary["weight"] as? Double,
            let age = dataDictionary["age"] as? Int32,
            let timeStamp = dataDictionary["timeStamp"] as? Date
        {
            self.firstName = firstName
            self.lastName = lastName
            self.zID = dataDictionary["zID"] as? RecordID
            self.weight = weight
            self.age = age
            self.timeStamp = timeStamp
        } else {
            return nil
        }
    }
    
    init(firstName: String, lastName: String, weight: Double, age: Int32, timeStamp: Date) {
        self.firstName = firstName
        self.lastName = lastName
        self.zID = nil
        self.weight = weight
        self.age = age
        self.timeStamp = timeStamp
    }
}

func createManager() -> DBManager {
    let paths = NSSearchPathForDirectoriesInDomains(.cachesDirectory, .userDomainMask, true)
    let documentsDirectory = paths[0] as NSString
    let fileName = "TestDB.sqlite"
    let logFilePath = documentsDirectory.appendingPathComponent(fileName)
    return DBManager(filePath: logFilePath, models: [Person.self])
}

class DBManager_SharedTests: XCTestCase {
    
    class func testDatabaseExists(dbManager: DBManager) {
        XCTAssert(dbManager.createDatabaseIfNotExist(), "Unable to create database, other tests may be in accurate")
    }
    
    class func testWriteReadTypes(dbManager: DBManager) {
        let person = Person(firstName: "Eric", lastName: "Schramm", weight: 123.456, age: 41, timeStamp: Date())
        let savedResult: Result<Person> = person.save(dbManager: dbManager)
        switch savedResult {
        case .success(let savedPerson):
            XCTAssert(savedPerson.firstName == "Eric",  ".text      - String mismatch")
            XCTAssert(savedPerson.weight == 123.456,    ".numeric   - Double mismatch")
            XCTAssert(savedPerson.age == 41,            ".integer   - Int32 mismatch")
        case .error(let error):
            XCTAssert(true, error)
        }
        
        /*
         case text
         case numeric
         case integer
         case recordID
         case real
         case blob
         case dateTime
         case bool           // 0 or 1
         */
    }

}
