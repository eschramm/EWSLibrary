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

public typealias RecordID = String

public protocol DBModel {
    static var table: DBTable { get }
    static var fields: [DBField] { get }
    var zID: RecordID? { get }
    static var zIDfieldOverride: String? { get }
    static var zIDfieldKeyOverride: String? { get }
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
    
    static func zIDfield() -> String {
        return zIDfieldOverride ?? "zID"
    }
    
    static func zIDfieldKey() -> String {
        return zIDfieldKeyOverride ?? "zID"
    }
    
    static func allFields() -> [DBField] {
        if zIDfield() != "zID" {
            return fields
        }
        var output = [DBField(keyName: zIDfield(), dbFieldName: nil, dataType: .recordID, constraints: [.notNull, .primaryKey, .autoIncrement])]
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
        if let primaryKey = dataDictionary[Self.zIDfield()] as? RecordID, dbManager.openDatabase() {
            defer {
                dbManager.database.close()
            }
            
            //check if networked
            if let networkings = dbManager.networkedNoDeletion[Self.table.dbTable()] {
                for networking in networkings {
                    let testStatement = "SELECT COUNT(\(networking.field)) FROM \(networking.table) WHERE \(networking.field)=?"
                    do {
                        let result = try dbManager.database.executeQuery(testStatement, values: [primaryKey])
                        if result.next(), result.int(forColumnIndex: 0) > 0 {
                            let count = result.int(forColumnIndex: 0)
                            return .error("Cannot delete \(Self.table.keyName) with zID=\(primaryKey) as this record is networked to \(count) records on field '\(networking.field)' in table '\(networking.table)'")
                        }
                    } catch {
                        let errorString = "Error retrieving \(networking.field) on )\(networking.table) for count for deletion permission check"
                        print(errorString)
                        return .error(errorString)
                    }
                }
            }
            
            let deleteStatement = "DELETE FROM \(Self.table.dbTable()) WHERE \(Self.zIDfield())=?"
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
        return .error("Error deleting '\(Self.table.keyName) - no primary key (\(Self.zIDfield())")
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
        
        if let recordID = dataDictionary[Self.zIDfield()] as? RecordID {
            var updateStatement = "UPDATE \(Self.table.dbTable()) SET "
            let fields = Self.allFields().map { (field) -> String in
                "\n\(field.dbField())=?"
                }.joined(separator: ", ")
            updateStatement += fields
            updateStatement += " \nWHERE \(Self.zIDfield())=?"
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
                    dataDict[Self.zIDfield()] = id
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
        if let aCache = dbManager.caches[Self.table.keyName] {
            cache = aCache
        } else {
            cache = RecordCache()
        }
        if let zID = record.zID {
            cache[zID] = record as DBModel
        } else {
            print("Attempting to cache record without a recordID (\(Self.zIDfield())!")
        }
        dbManager.caches[Self.table.keyName] = cache
    }
    
    static func fetch<T>(for IDs: [RecordID], dbManager: DBManager, skipCache: Bool = false) -> Result<[T]> {
        
        let startTime = mach_absolute_time()
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
                let result = try dbManager.database.executeQuery("SELECT * FROM \(Self.table.dbTable()) WHERE \(zIDfield()) IN (\(queryQuestionMarks))", values: faultedIDs)
                dbManager.queryCount += 1
                while result.next() {
                    let recordAndID : RecordAndID<T> = record(for: result, dbManager: dbManager)
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
        if dbManager.debugMode {
            print("Query from IDs: '\(faultedIDs)'")
            print("Cache Saves: \(IDs.count - faultedIDs.count)")
            print("Query Time: \(timeStampDiff(start: startTime, end: mach_absolute_time()))")
        }
        return Result.success(IDs.map({ (recordID) -> T in
            cache[recordID] as! T
        }))
    }
    
    static func fetchIDs(for query: String, values: [Any], dbManager: DBManager, skipCache: Bool = false) -> Result<[RecordID]> {
        guard dbManager.openDatabase()  else {
            let errorString = "Error opening database - returning empty array of IDs"
            print(errorString)
            return .error(errorString)
        }
        defer {
            dbManager.database.close()
        }
        let startTime = mach_absolute_time()
        var ids = [RecordID]()
        do {
            let results = try dbManager.database.executeQuery(query, values: values)
            dbManager.queryCount += 1
            while(results.next()) {
                if let id = results.string(forColumn: Self.zIDfield()) {
                    ids.append(id)
                }
            }
        } catch {
            let errorString = "Error fetching with query '\(query)' - returning empty array of IDs"
            print(errorString)
            return .error(errorString)
        }
        if dbManager.debugMode {
            print("Query IDs: '\(query)' with values '\(values)'")
            print("Query Time: \(timeStampDiff(start: startTime, end: mach_absolute_time()))")
        }
        return .success(ids)
    }
    
    static func fetch<T>(for query: String, values: [Any], dbManager: DBManager, skipCache: Bool = false) -> Result<[T]> {
        guard dbManager.openDatabase()  else {
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
    
    static func record<T>(for result: FMResultSet, dbManager: DBManager) -> RecordAndID<T> {
        var dataDict = [String : Any]()
        for field in Self.allFields() {
            //check for nulls, first
            let value: Any
            if !field.constraints.contains(.notNull), let _ = result.object(forColumn: field.dbField()) as? NSNull {
                value = NSNull()
            } else {
                switch field.dataType {
                case .text:
                    value = result.string(forColumn: field.dbField()) as Any
                case .numeric:
                    value = result.double(forColumn: field.dbField()) as Any
                case .integer:
                    value = result.int(forColumn: field.dbField()) as Any   //returns an Int32 by default
                case .recordID:
                    value = result.string(forColumn: field.dbField()) as Any
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
            }
            dataDict[field.keyName] = value
        }
        let record = Self.init(dataDictionary: dataDict) as? T
        let id = dataDict[zIDfieldKey()] as? RecordID
        return RecordAndID(record: record, id: id)
    }
}

public struct RecordAndID<T> {
    let record: T?
    let id: RecordID?
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

public enum SQLConstraints : Hashable, Equatable {
    //see: https://www.w3schools.com/sql/sql_constraints.asp
    case unique
    case primaryKey
    case autoIncrement
    case notNull
    case noDeletionIfNetworked(toTable: TableName)
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
        case .noDeletionIfNetworked(toTable: _):
            return ""
            /* case .foreignKey(let toTable, let toField):
             return "FOREIGN KEY(\(forField.DBFieldName ?? forField.keyName) REFERENCES \(toTable.DBTableName ?? toTable.keyName)(\(toField.DBFieldName ?? toField.keyName)"  //FOREIGN KEY(trackartist) REFERENCES artist(artistid)
             case .check(let evalPredicate):
             
             case .hasDefault(let defaultValue):
             */
        }
    }
    
    func sortValue() -> Int {
        switch self {
        case .primaryKey:
            return 0
        case .autoIncrement:
            return 1
        case .notNull:
            return 2
        case .unique:
            return 3
        case .noDeletionIfNetworked(toTable: _):
            return 4
        }
    }
}

public struct DBTable: Equatable, Hashable {
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

public struct DBField : Equatable, Hashable {
    
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
            constraint1.sortValue() < constraint2.sortValue()
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

public struct DBIndex: Equatable, Hashable {
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
public typealias TableName = String
public typealias FieldName = String

struct Networking {
    let table: TableName
    let field: FieldName
}

public extension DBManager {
    public static let didCompleteInitialization = Notification.Name("DBManagerDidCompleteInitialization")
}

public class DBManager {
    
    public let filePath: String
    public let models: [DBModel.Type]
    public private(set) var database: FMDatabase!
    public var debugMode = false
    var caches = [String : RecordCache]()
    var cacheSaves = 0
    var queryCount = 0
    let numberFormatter = NumberFormatter()
    var networkedNoDeletion = [TableName : [Networking]]()
    
    public let sqlDateFormatter = DateFormatter()
    
    public init(filePath: String, models: [DBModel.Type]) {
        self.filePath = filePath
        self.models = models
        sqlDateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss"
        numberFormatter.numberStyle = .decimal
        populateNetworkedNoDeletion()
        NotificationCenter.default.post(name: DBManager.didCompleteInitialization, object: self, userInfo: nil)
    }
    
    public func createDatabaseIfNotExistAndOpen() -> Bool {
        return openDatabase()
    }
    
    public func createTable(model: DBModel.Type) -> Bool {
        guard database != nil else {
            print("database is null")
            return false
        }
        var created = false
        var statements = [String]()
        statements.append(model.createTableStatement())
        let indexStatement = model.createIndexesStatement()
        if !indexStatement.isEmpty {
            statements.append(indexStatement)
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
        return created
    }
    
    public func nukeDatabase() {
        database = nil
        do {
            try FileManager.default.removeItem(atPath: filePath)
        } catch {
            print("Error deleting database at \(filePath)")
        }
    }
    
    fileprivate func populateNetworkedNoDeletion() {
        for model in models {
            for field in model.fields {
                var networkedTable: TableName?
                if field.constraints.contains(where: { constraint in
                    if case SQLConstraints.noDeletionIfNetworked(let tableName) = constraint {
                        networkedTable = tableName
                        return true
                    }
                    return false
                }), let networkedTable = networkedTable
                {
                    var networkedFields = networkedNoDeletion[networkedTable] ?? [Networking]()
                    networkedFields.append(Networking(table: model.table.dbTable(), field: field.dbField()))
                    networkedNoDeletion[networkedTable] = networkedFields
                }
            }
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
        print("Query Count: \(numberFormatter.string(from: NSNumber(value: queryCount))!)")
        for (key, value) in caches {
            print("Cache - '\(key)'")
            print(" - \(numberFormatter.string(from: NSNumber(value: value.count))!) records")
        }
    }
}

func timeStampDiff(start: UInt64, end: UInt64) -> String {
    let diffInNanoseconds = end - start
    let diffInSeconds = Double(Double(Int(Double(diffInNanoseconds) / 1_000_000_000 * 10000)) / 10000)  //round to four decimal places
    return "\(diffInSeconds) seconds"
}
