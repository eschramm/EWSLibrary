//
//  CSVHelpers.swift
//  EWSLibrary
//
//  Created by Eric Schramm on 9/2/24.
//

import Foundation

public extension DateFormatter {
    static let exportExplorer: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS"
        df.timeZone = .init(secondsFromGMT: 0)
        return df
    }()
}

public protocol StringConvertableEnum : RawRepresentable {
    init?(string: String)
}

public enum CSVImporterError: Error {
    case cannotCreateUUID(uuidString: String, field: String)
    case cannotCreateDate(dateString: String, field: String)
    case cannotCreateEnum(rawString: String, field: String, type: String)
    case cannotCreateInt(rawString: String, field: String)
}

/// can be used to collect items inside the CSVFileParser processor closure
public actor AsyncArray<T : Sendable> {
    
    public var items: [T]
    
    public init() {
        self.items = []
    }
    
    public nonisolated func addItem(_ item: T) {
        Task {
            await self.addItem(item: item)
        }
    }
    
    private func addItem(item: T) {
        items.append(item)
    }
}

public extension Array where Element == String {
    
    func i<E: RawRepresentable>(mapping: [E : Int], field: E, emptyStringIfNotMapped: Bool = false) -> String where E.RawValue == String {
        if emptyStringIfNotMapped, !mapping.keys.contains(field) {
            return ""
        } else {
            return self[mapping[field]!]
        }
    }
    func iDate<E: RawRepresentable>(mapping: [E : Int], field: E) throws -> Date where E.RawValue == String {
        let stringValue = self[mapping[field]!]
        guard let date = DateFormatter.exportExplorer.date(from: stringValue) else {
            throw CSVImporterError.cannotCreateDate(dateString: stringValue, field: field.rawValue)
        }
        return date
    }
    func iDateOpt<E: RawRepresentable>(mapping: [E : Int], field: E, nilIfNotMapped: Bool = false) throws -> Date? where E.RawValue == String {
        if nilIfNotMapped, !mapping.keys.contains(field) {
            return nil
        } else {
            let stringValue = self[mapping[field]!]
            guard !stringValue.isEmpty else {
                return nil
            }
            guard let date = DateFormatter.exportExplorer.date(from: stringValue) else {
                throw CSVImporterError.cannotCreateDate(dateString: stringValue, field: field.rawValue)
            }
            return date
        }
    }
    func iUUID<E: RawRepresentable>(mapping: [E : Int], field: E) throws -> UUID where E.RawValue == String {
        let stringValue = self[mapping[field]!]
        guard let uuid = UUID(uuidString: stringValue) else {
            throw CSVImporterError.cannotCreateUUID(uuidString: stringValue, field: field.rawValue)
        }
        return uuid
    }
    func iUUIDOpt<E: RawRepresentable>(mapping: [E : Int], field: E, nilIfNotMapped: Bool = false) throws -> UUID? where E.RawValue == String {
        if nilIfNotMapped, !mapping.keys.contains(field) {
            return nil
        } else {
            let stringValue = self[mapping[field]!]
            if stringValue.isEmpty {
                return nil
            }
            guard let uuid = UUID(uuidString: stringValue) else {
                throw CSVImporterError.cannotCreateUUID(uuidString: stringValue, field: field.rawValue)
            }
            return uuid
        }
    }
    func iSEnum<E: RawRepresentable, T: RawRepresentable>(mapping: [E : Int], field: E) throws -> T where E.RawValue == String, T.RawValue == String {
        let stringValue = self[mapping[field]!]
        guard let enumValue = T.init(rawValue: stringValue) else {
            throw CSVImporterError.cannotCreateEnum(rawString: stringValue, field: field.rawValue, type: "\(T.self)")
        }
        return enumValue
    }
    func iSEnumOpt<E: RawRepresentable, T: RawRepresentable>(mapping: [E : Int], field: E, nilIfNotMapped: Bool = false) throws -> T? where E.RawValue == String, T.RawValue == String {
        if nilIfNotMapped, !mapping.keys.contains(field) {
            return nil
        } else {
            let stringValue = self[mapping[field]!]
            guard !stringValue.isEmpty else {
                return nil
            }
            guard let enumValue = T.init(rawValue: stringValue) else {
                throw CSVImporterError.cannotCreateEnum(rawString: stringValue, field: field.rawValue, type: "\(T.self)")
            }
            return enumValue
        }
    }
    func iIEnum<E: RawRepresentable, T: StringConvertableEnum>(mapping: [E : Int], field: E) throws -> T where E.RawValue == String, T.RawValue == Int {
        let stringValue = self[mapping[field]!]
        guard let enumValue = T.init(string: stringValue) else {
            throw CSVImporterError.cannotCreateEnum(rawString: stringValue, field: field.rawValue, type: "\(T.self)")
        }
        return enumValue
    }
    func iInt<E: RawRepresentable>(mapping: [E : Int], field: E) throws -> Int where E.RawValue == String {
        let stringValue = self[mapping[field]!]
        guard let int = Int(stringValue) else {
            throw CSVImporterError.cannotCreateInt(rawString: stringValue, field: field.rawValue)
        }
        return int
    }
    func iData<E: RawRepresentable>(mapping: [E : Int], field: E) -> Data where E.RawValue == String {
        let stringValue = self[mapping[field]!]
        return stringValue.data(using: .utf8)!
    }
    func iBool<E: RawRepresentable>(mapping: [E : Int], field: E) -> Bool where E.RawValue == String {
        let stringValue = self[mapping[field]!].lowercased() as NSString
        return stringValue.boolValue
    }
    func iBoolOpt<E: RawRepresentable>(mapping: [E : Int], field: E, nilIfNotMapped: Bool = false) -> Bool? where E.RawValue == String {
        if nilIfNotMapped, !mapping.keys.contains(field) {
            return nil
        } else {
            let stringValue = self[mapping[field]!].lowercased() as NSString
            return stringValue.boolValue
        }
    }
}

/*
 Example of ModelConverter
 
 enum AField: String, CaseIterable {
     case participantIdentifier = "participantidentifier"
     case timeStamp = "timestamp"
     //case participantid
     case type = "type"
     case properties = "properties"
     //case provenance = "_provenance"
 }
 
 static func makeModelConverter(fieldMap: [AField : Int]) -> @Sendable ([String]) -> Result<AnalyticsEvent, CSVLineError> {
     return { fields in
         /*
          HKv1
          0                    1                       2      3           4      5       6       7                  8            9               10           11            12                   13                      14                      15
          "healthkitsamplekey","participantidentifier","type","startdate","date","value","units","sourceidentifier","sourcename","sourceversion","devicename","devicemodel","devicemanufacturer","devicehardwareversion","devicesoftwareversion","devicefirmwareversion","devicelocalidentifier","devicefdaidentifier","metadata","inserteddate","_provenance"
          "5DB9C248-3B89-EC11-AAB6-0AFB9334277D","37","Steps","2022-02-08 23:19:01.000","2022-02-08 23:26:21.000","133","count","com.apple.health.79B9099E-61CB-4DE6-8245-7720BD4C8B19","Paco’s Apple Watch","8.4","Apple Watch","Watch","Apple Inc.","Watch3,4","8.4",,,,"{}","2022-02-09 00:00:36.000","{exportstartdate=2022-02-09T00:00:00+00:00, s3key=RK.EA478515.Constellation/8c7dee17-30d5-44d7-80a1-e8ae297614aa, updatedate=2023-05-06T18:17:26.710114+00:00, s3bucket=pep-rkstudio-export, appversion=1.0.0, exportenddate=2022-02-10T00:00:00+00:00}"
          */
         do {
             let propertiesString = fields.i(mapping: fieldMap, field: .properties)
             let properties = AnalyticsModelConverter.propertiesToDict(string: propertiesString)
             return .success(.init(
                 pid: fields[0],
                 timeStamp: try fields.iDate(mapping: fieldMap, field: .timeStamp),
                 type: try fields.iSEnum(mapping: fieldMap, field: .type),
                 properties: properties)
             )
         } catch {
             print("ModelConversionError: \(error)")
             return .failure(.error(line: fields, error: error))
         }
     }
 }
 */
