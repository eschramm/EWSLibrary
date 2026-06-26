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

public extension Date {
    /// Fast, lock-free parse of the fixed `yyyy-MM-dd HH:mm:ss.SSS` UTC format used by MDH exports.
    ///
    /// `DateFormatter.date(from:)` costs ~20µs/call and, because a shared formatter serializes on
    /// an internal lock, becomes a hard bottleneck when many threads parse concurrently. This parser
    /// is ~200x faster and lock-free. It returns `nil` for anything that doesn't match the format
    /// exactly, so callers can fall back to the lenient `DateFormatter`.
    static func fromExportExplorerUTC(_ string: String) -> Date? {
        let b = Array(string.utf8)
        guard b.count == 23 else { return nil }

        @inline(__always) func digit(_ i: Int) -> Int? {
            let v = Int(b[i]) - 48
            return (v >= 0 && v <= 9) ? v : nil
        }
        // separators: 2025-10-22 14:56:45.000
        guard b[4] == 0x2D, b[7] == 0x2D, b[10] == 0x20, b[13] == 0x3A, b[16] == 0x3A, b[19] == 0x2E else { return nil }
        guard let y0 = digit(0), let y1 = digit(1), let y2 = digit(2), let y3 = digit(3),
              let mo0 = digit(5), let mo1 = digit(6),
              let d0 = digit(8), let d1 = digit(9),
              let h0 = digit(11), let h1 = digit(12),
              let mi0 = digit(14), let mi1 = digit(15),
              let s0 = digit(17), let s1 = digit(18),
              let ms0 = digit(20), let ms1 = digit(21), let ms2 = digit(22) else { return nil }

        let year = y0 * 1000 + y1 * 100 + y2 * 10 + y3
        let month = mo0 * 10 + mo1
        let day = d0 * 10 + d1
        let hour = h0 * 10 + h1
        let minute = mi0 * 10 + mi1
        let second = s0 * 10 + s1
        let millis = ms0 * 100 + ms1 * 10 + ms2
        guard month >= 1, month <= 12, day >= 1, day <= 31, hour <= 23, minute <= 59, second <= 60 else { return nil }

        // days from civil (Howard Hinnant's algorithm), UTC
        let y = month <= 2 ? year - 1 : year
        let era = (y >= 0 ? y : y - 399) / 400
        let yoe = y - era * 400
        let doy = (153 * (month + (month > 2 ? -3 : 9)) + 2) / 5 + day - 1
        let doe = yoe * 365 + yoe / 4 - yoe / 100 + doy
        let days = era * 146097 + doe - 719468
        let seconds = Double(days * 86400 + hour * 3600 + minute * 60 + second) + Double(millis) / 1000.0
        return Date(timeIntervalSince1970: seconds)
    }
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
    
    /// Fire-and-forget convenience; does NOT guarantee ordering or completion before caller continues.
    @available(*, deprecated, message: "Use 'await addItem(item:)' directly for guaranteed ordering")
    public nonisolated func addItem(_ item: T) {
        Task {
            await self.addItem(item: item)
        }
    }
    
    public func addItem(item: T) {
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
        // Fast lock-free path for the canonical format; fall back to the lenient formatter otherwise.
        guard let date = Date.fromExportExplorerUTC(stringValue) ?? DateFormatter.exportExplorer.date(from: stringValue) else {
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
            guard let date = Date.fromExportExplorerUTC(stringValue) ?? DateFormatter.exportExplorer.date(from: stringValue) else {
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
