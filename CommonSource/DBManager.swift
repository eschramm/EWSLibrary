//
//  DBManager.swift
//  EWSLibrary_iOS
//
//  Created by Eric Schramm on 7/24/18.
//  Copyright © 2018 eware. All rights reserved.
//

import Foundation

//see: https://www.appcoda.com/fmdb-sqlite-database/

import Foundation
import FMDB

public typealias RecordID = Int32

public protocol DBModel {
    static var table: DBTable { get }
    static var fields: [DBField] { get }
    var zID: RecordID? { get }
    var dataDictionary: [String : Any] { get }
    init?(dataDictionary: [String : Any])
}

public enum Result<T> {
    case success(T)
    case error(String)
}

public enum Success {
    case success
    case error(String)
}

public extension DBModel {
    
    static func allFields() -> [DBField] {
        var output = [DBField(keyName: "zID", dbFieldName: nil, dataType: .recordID, constraints: [.notNull, .primaryKey, .autoIncrement])]
        output.append(contentsOf: fields)
        return output
    }
    
    static func createTableStatement() -> String {
        
        var output = "CREATE TABLE \(table.dbTable()) ("
        
        let fieldsString = allFields().map { (field) -> String in
            "\n\(field.dbField()) \(field.dataType.statementText()) \(field.constraintsStatement())"
            }.joined(separator: ", ")
        output += "\(fieldsString));"
        
        return output
    }
    
    static func createIndexesStatement() -> String {
        var output = ""
        for index in table.indexes {
            let fields = index.fields.map { (field) -> String in
                field.dbField()
                }.joined(separator: ", ")
            output += "\nCREATE \(index.unique ? "UNIQUE " : "")INDEX \(index.name) ON \(table.dbTable()) (\(fields));"
        }
        return output
    }
    
    func delete(dbManager: DBManager) -> Success {
        if let primaryKey = dataDictionary["zID"] as? RecordID, dbManager.openDatabase() {
            defer {
                dbManager.database.close()
            }
            let deleteStatement = "DELETE FROM \(Self.table.dbTable()) WHERE zID=?"
            do {
                try dbManager.database.executeUpdate(deleteStatement, values: [primaryKey])
                //delete from cache
                if var cache = dbManager.caches[Self.table.dbTable()] {
                    cache.removeValue(forKey: primaryKey)
                }
                return .success
            } catch {
                print(error.localizedDescription)
                return .error("Error deleting '\(Self.table.keyName)'\n\(error.localizedDescription)")
            }
        }
        return .error("Error deleting '\(Self.table.keyName) - no primary key (zID)")
    }
    
    func save<T>(dbManager: DBManager) -> Result<T> {
        
        guard dbManager.openDatabase() else {
            let errorString = "Database is not open, unable to save \(Self.table.keyName)"
            print(errorString)
            return Result.error(errorString)
        }
        
        defer {
            dbManager.database.close()
        }
        
        if let recordID = dataDictionary["zID"] as? RecordID {
            var updateStatement = "UPDATE \(Self.table.dbTable()) SET "
            let fields = Self.allFields().map { (field) -> String in
                "\n\(field.dbField())=?"
                }.joined(separator: ", ")
            updateStatement += fields
            updateStatement += " \nWHERE zID=?"
            var values = Self.allFields().map { (field) -> Any in
                let value = dataDictionary[field.keyName]
                if let date = value as? Date {
                    return "\(dbManager.sqlDateFormatter.string(from: date))"
                } else {
                    return dataDictionary[field.keyName] ?? NSNull()
                }
            }
            values.append(recordID)
            do {
                try dbManager.database.executeUpdate(updateStatement, values: values)
                updateCache(record: self, dbManager: dbManager)
                return Result.success(self as! T)
            } catch {
                let errorString = "Error saving existing \(Self.table.keyName) with id:\(recordID)\n\(error.localizedDescription)"
                print(errorString)
                return Result.error(errorString)
            }
        } else {
            var updateStatement = "INSERT INTO \(Self.table.dbTable()) (\n"
            var fields = [String]()
            var questionMarks = [String]()
            var values = [Any]()
            for field in Self.allFields() {
                fields.append(field.dbField())
                questionMarks.append("?")
                let value = dataDictionary[field.keyName]
                if let date = value as? Date {
                    values.append("\(dbManager.sqlDateFormatter.string(from: date))")
                } else {
                    values.append(dataDictionary[field.keyName] ?? NSNull())
                }
            }
            updateStatement += fields.joined(separator: ", \n")
            updateStatement += "\n)\nVALUES (\(questionMarks.joined(separator: ", ")));"
            do {
                try dbManager.database.executeUpdate(updateStatement, values: values)
            } catch {
                let errorString = "Error saving new \(Self.table.keyName). \(error.localizedDescription)"
                print(errorString)
                return Result.error(errorString)
            }
            do {
                let rowIDresult = try dbManager.database.executeQuery("SELECT last_insert_rowid()", values: nil)
                if rowIDresult.next() {
                    let id = RecordID(rowIDresult.int(forColumnIndex: 0))
                    var dataDict = [String : Any]()
                    for field in Self.allFields() {
                        dataDict[field.keyName] = dataDictionary[field.keyName]
                    }
                    dataDict["zID"] = id
                    let record = Self.init(dataDictionary: dataDict) as! T
                    updateCache(record: record as! Self, dbManager: dbManager)
                    return Result.success(record)
                }
            } catch {
                let errorString = "Error getting last row ID upon creation of \(Self.table.keyName)\n\(error.localizedDescription)"
                print(errorString)
                return Result.error(errorString)
            }
        }
        return Result.error("Unknown error occurred")
    }
    
    private func updateCache(record: Self, dbManager: DBManager) {
        var cache: RecordCache
        if let aCache = dbManager.caches[Self.table.dbTable()] {
            cache = aCache
        } else {
            cache = RecordCache()
        }
        if let zID = record.zID {
            cache[zID] = record as DBModel
        } else {
            print("Attempting to cache record without a recordID (zID)!")
        }
        dbManager.caches[Self.table.dbTable()] = cache
    }
    
    static func fetch<T>(for IDs: [RecordID], dbManager: DBManager, skipCache: Bool) -> Result<[T]> {
        
        var faultedIDs = [RecordID]()
        if !skipCache, let cache = dbManager.caches[table.keyName] {
            for id in IDs {
                if cache[id] == nil {
                    faultedIDs.append(id)
                } else {
                    dbManager.cacheSaves += 1
                }
            }
        } else {
            faultedIDs = IDs
        }
        
        var cache: RecordCache
        if let aCache = dbManager.caches[table.keyName] {
            cache = aCache
        } else {
            cache = RecordCache()
        }
        
        if !faultedIDs.isEmpty, dbManager.openDatabase() {
            defer {
                dbManager.database.close()
            }
            let queryQuestionMarks = String(repeating: "?, ", count: faultedIDs.count - 1) + "?"
            
            do {
                let result = try dbManager.database.executeQuery("SELECT * FROM \(Self.table.dbTable()) WHERE zID IN (\(queryQuestionMarks))", values: faultedIDs)
                while result.next() {
                    let recordAndID: (record: T?, id: RecordID?) = record(for: result, dbManager: dbManager)
                    if let record = recordAndID.record, let id = recordAndID.id {
                        cache[id] = record as? DBModel
                    }
                }
            } catch {
                let errorString = "Error retrieving \(Self.table.keyName) for IDs='\(IDs)' - returning empty array of \(Self.table.keyName)\n\(error)"
                print(errorString)
                return .error(errorString)
            }
            dbManager.caches[table.keyName] = cache
        }
        return Result.success(IDs.map({ (recordID) -> T in
            cache[recordID] as! T
        }))
    }
    
    static func fetchIDs(for query: String, values: [Any], dbManager: DBManager, skipCache: Bool) -> Result<[RecordID]> {
        guard dbManager.database.open() else {
            let errorString = "Error opening database - returning empty array of IDs"
            print(errorString)
            return .error(errorString)
        }
        defer {
            dbManager.database.close()
        }
        var ids = [RecordID]()
        do {
            let results = try dbManager.database.executeQuery(query, values: values)
            while(results.next()) {
                ids.append(RecordID(results.int(forColumn: "zID")))
            }
        } catch {
            let errorString = "Error fetching with query '\(query)' - returning empty array of IDs"
            print(errorString)
            return .error(errorString)
        }
        return .success(ids)
    }
    
    static func fetch<T>(for query: String, values: [Any], dbManager: DBManager, skipCache: Bool) -> Result<[T]> {
        
        guard dbManager.database.open() else {
            let errorString = "Error opening database - returning empty array of \(Self.table.keyName)"
            print(errorString)
            return Result.error(errorString)
        }
        let idsResult = fetchIDs(for: query, values: values, dbManager: dbManager, skipCache: skipCache)
        switch idsResult {
        case .success(let ids):
            return fetch(for: ids, dbManager: dbManager, skipCache: skipCache)
        case .error(let error):
            return .error(error)
        }
    }
    
    static func record<T>(for result: FMResultSet, dbManager: DBManager) -> (record: T?, id: RecordID?) {
        var dataDict = [String : Any]()
        for field in Self.allFields() {
            let value: Any
            switch field.dataType {
            case .text:
                value = result.string(forColumn: field.dbField()) as Any
            case .numeric:
                value = result.double(forColumn: field.dbField()) as Any
            case .integer:
                value = result.int(forColumn: field.dbField()) as Any   //returns an Int32 by default
            case .recordID:
                value = RecordID(result.int(forColumn: field.dbField())) as Any
            case .real:
                value = result.double(forColumn: field.dbField()) as Any
            case .blob:
                value = result.data(forColumn: field.dbField()) as Any
            case .dateTime:
                if let stringDate = result.string(forColumn: field.dbField()) {
                    value = dbManager.sqlDateFormatter.date(from: stringDate) as Any
                } else {
                    value = NSNull()
                }
            case .bool:
                value = (result.int(forColumn: field.dbField()) == 1) as Any
            }
            dataDict[field.keyName] = value
        }
        return (Self.init(dataDictionary: dataDict) as? T, dataDict["zID"] as? RecordID)
    }
}

public enum SQLDataType {
    //see: https://www.sqlite.org/datatype3.html
    case text
    case numeric
    case integer
    case recordID
    case real
    case blob
    case dateTime
    case bool           // 0 or 1
    
    func statementText() -> String {
        switch self {
        case .text:
            return "TEXT"
        case .numeric:
            return "NUMERIC"
        case .integer:
            return "INTEGER"
        case .recordID:
            return "INTEGER"
        case .real:
            return "REAL"
        case .blob:
            return "BLOB"
        case .dateTime:
            return "DATETIME"
        case .bool:
            return "INTEGER"
        }
    }
}

public enum SQLConstraints: Int {
    //see: https://www.w3schools.com/sql/sql_constraints.asp
    case unique
    case primaryKey
    case autoIncrement
    case notNull
    //case foreignKey(toTable: DBTable, toField: DBField)
    //case check(evalPredicate: String)
    //case hasDefault(defaultValue: String)
    
    func statementText() -> String {
        switch self {
        case .autoIncrement:
            return "AUTOINCREMENT"
        case .notNull:
            return "NOT NULL"
        case .unique:
            return "UNIQUE"
        case .primaryKey:
            return "PRIMARY KEY"
            /* case .foreignKey(let toTable, let toField):
             return "FOREIGN KEY(\(forField.DBFieldName ?? forField.keyName) REFERENCES \(toTable.DBTableName ?? toTable.keyName)(\(toField.DBFieldName ?? toField.keyName)"  //FOREIGN KEY(trackartist) REFERENCES artist(artistid)
             case .check(let evalPredicate):
             
             case .hasDefault(let defaultValue):
             */
        }
    }
}

public struct DBTable {
    public let keyName: String
    public let dbTableName: String?
    public let indexes: [DBIndex]
    
    public init(keyName: String, dbTableName: String?, indexes: [DBIndex]) {
        self.keyName = keyName
        self.dbTableName = dbTableName
        self.indexes = indexes
    }
    
    public func dbTable() -> String {
        return dbTableName ?? keyName
    }
}

public struct DBField : Equatable {
    
    public let keyName: String
    public let dbFieldName: String?
    public let dataType: SQLDataType
    public let constraints: Set<SQLConstraints>
    
    public init(keyName: String, dbFieldName: String?, dataType: SQLDataType, constraints: Set<SQLConstraints>) {
        self.keyName = keyName
        self.dbFieldName = dbFieldName
        self.dataType = dataType
        self.constraints = constraints
    }
    
    public func dbField() -> String {
        return dbFieldName ?? keyName
    }
    
    func constraintsStatement() -> String {
        let sortedConstraints = constraints.sorted { (constraint1, constraint2) -> Bool in
            constraint1.rawValue < constraint2.rawValue
        }
        let constraintsStrings = sortedConstraints.map { (constraint) -> String in
            constraint.statementText()
        }
        return constraintsStrings.joined(separator: " ")
    }
    
    public static func == (lhs: DBField, rhs: DBField) -> Bool {
        return lhs.keyName == rhs.keyName
    }
}

public struct DBIndex {
    public let name: String
    public let fields: [DBField]
    public let unique: Bool
    
    public init(name: String, fields: [DBField], unique: Bool) {
        self.name = name
        self.fields = fields
        self.unique = unique
    }
}

typealias RecordCache = [RecordID : DBModel]

public class DBManager {
    
    public let filePath: String
    public let models: [DBModel.Type]
    public private(set) var database: FMDatabase!
    var caches = [String : RecordCache]()
    var cacheSaves = 0
    let numberFormatter = NumberFormatter()
    
    public let sqlDateFormatter = DateFormatter()
    
    public init(filePath: String, models: [DBModel.Type]) {
        self.filePath = filePath
        self.models = models
        sqlDateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        numberFormatter.numberStyle = .decimal
    }
    
    public func createDatabaseIfNotExist() -> Bool {
        return openDatabase()
    }
    
    public func nukeDatabase() {
        database = nil
        do {
            try FileManager.default.removeItem(atPath: filePath)
        } catch {
            print("Error deleting database at \(filePath)")
        }
    }
    
    fileprivate func openDatabase() -> Bool {
        if database == nil {
            if FileManager.default.fileExists(atPath: filePath) {
                database = FMDatabase(path: filePath)
            } else {
                return createDatabase()
            }
        }
        
        if database != nil {
            if database.open() {
                return true
            }
        }
        return false
    }
    
    fileprivate class func valueForOptional(value: CustomStringConvertible?) -> String {
        return value != nil ? "\(value!)" : "null"
    }
    
    fileprivate class func boolValue(bool: Bool) -> String {
        if bool {
            return "1"
        } else {
            return "0"
        }
    }
    
    private func createDatabase() -> Bool {
        var created = false
        
        if !FileManager.default.fileExists(atPath: filePath) {
            database = FMDatabase(path: filePath)
            
            if database != nil {
                var statements = [String]()
                for model in models {
                    statements.append(model.createTableStatement())
                    let indexStatement = model.createIndexesStatement()
                    if !indexStatement.isEmpty {
                        statements.append(indexStatement)
                    }
                }
                for statement in statements {
                    //print(statement)
                    // Open the database.
                    if database.open() {
                        do {
                            try database.executeUpdate(statement, values: nil)
                            created = true
                        }
                        catch {
                            print("Could not create table.")
                            print(error.localizedDescription)
                        }
                        // At the end close the database.
                        database.close()
                    } else {
                        print("Could not open the database.")
                    }
                }
            }
        }
        
        return created
    }
    
    public func cacheStatus() {
        print("Cache Saves: \(numberFormatter.string(from: NSNumber(value: cacheSaves))!)")
        for (key, value) in caches {
            print("Cache - '\(key)'")
            print(" - \(numberFormatter.string(from: NSNumber(value: value.count))!) records")
        }
    }
}
