//
//  File.swift
//  
//
//  Created by Eric Schramm on 1/3/22.
//

import Foundation

public extension Date {
    /*
     NOTE about Calendar. Don't store and pass it around. Always attempt to pull it fresh.
     It should only be injected into these when performing tests where one may want to set
     the calendar a certain way (e.g., DST vs ST)
     */
    
    var truncateToNoon: Date {
        return Calendar.current.date(bySettingHour: 12, minute: 0, second: 0, of: self)!
    }
    
    private func truncateToNoonTesting(calendar: Calendar) -> Date {
        return calendar.date(bySettingHour: 12, minute: 0, second: 0, of: self)!
    }
    
    var truncateToMidnight: Date? {
        return Calendar.current.date(bySettingHour: 0, minute: 0, second: 0, of: self)
    }
    
    private func truncateToMidnight(calendar: Calendar = .current) -> Date? {
        return calendar.date(bySettingHour: 0, minute: 0, second: 0, of: self)
    }
    
    /// NOTE: returns sortedDates.count (index that doesn't exist) for case where date exceeds the last in the array
    func nextIndex(for sortedDates: [Date]) -> (nextIndex: Int, iterations: Int) {
        // binary search
        var iterations = 0
        var left = 0
        var right = sortedDates.count - 1
        var middle = -1
        var foundIndex = -1
        
        while left <= right {
            iterations += 1
            middle = (left + right) / 2
            if sortedDates[middle] < self {
                left = middle + 1
            } else if sortedDates[middle] > self {
                right = middle - 1
            } else {
                foundIndex = middle
                break
            }
        }
        
        if foundIndex == -1 {  // not found, right should be just last index before nextDate
            foundIndex = right
        }
        return (foundIndex + 1, iterations)
    }
    
    /// Binary search of dates array for performance
    /// - Parameter sortedDates: list of dates sorted ascending
    /// - Returns: index of date preceding or matching self, `nil` if date precedes all sortedDates
    func previousIndex(for sortedDates: [Date]) -> Int? {
        // binary search
        var left = 0
        var right = sortedDates.count - 1
        var middle = -1
        var foundIndex: Int? = -1
        
        while left <= right {
            middle = (left + right) / 2
            if sortedDates[middle] < self {
                left = middle + 1
            } else if sortedDates[middle] > self {
                right = middle - 1
            } else {
                foundIndex = middle
                break
            }
        }
        
        if foundIndex == -1 {
            foundIndex = (right != -1) ? right : nil
        }
        return foundIndex
    }
    
    struct InsideIntervalsRunInfo {
        public let iterations: Int
        public let closestIntervals: [DateInterval]
    }
    
    func containedInsideIntervals(sortedIntervals: [DateInterval]) -> (isContainedInAnInterval: Bool, runInfo: InsideIntervalsRunInfo) {
        
        var iterations = 0
        
        guard !sortedIntervals.isEmpty else {
            return (false, .init(iterations: 0, closestIntervals: []))
        }
        guard self <= sortedIntervals.last!.end else {
            return (false, .init(iterations: 0, closestIntervals: []))
        }
        guard self >= sortedIntervals[0].start else {
            return (false, .init(iterations: 0, closestIntervals: []))
        }
        
        // binary search
        var left = 0
        var right = sortedIntervals.count - 1
        var middle = -1
        
        while left <= right {
            middle = (left + right) / 2
            // print("\(left) - \(middle) - \(right)")
            let interval = sortedIntervals[middle]
            if interval.contains(self) {
                return (true, .init(iterations: iterations, closestIntervals: [interval]))
            } else if interval.end < self {
                left = middle + 1
            } else if interval.start > self {
                right = middle - 1
            } else {
                break
            }
            iterations += 1
        }
        
        return (false, .init(iterations: iterations, closestIntervals: [sortedIntervals[min(left, right)], sortedIntervals[max(left, right)]]))
    }
    
    var lastDateOfMonth: Date {
        let range = Calendar.current.range(of: .day, in: .month, for: self)!
        return Calendar.current.date(bySetting: .day, value: range.count, of: self)!
    }
}

public extension DateInterval {
    
    typealias DateString = String
    
    static let dateStringFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateFormat = "yyyy-MM-dd"
        return df
    }()
    
    static let dateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .short
        df.timeStyle = .long
        return df
    }()
    
    static let timeFormatter: DateFormatter = {
        let df = DateFormatter()
        df.timeStyle = .long
        return df
    }()
    
    static let dateOnlyFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .short
        return df
    }()
    
    func debugDescription(showStartDate: Bool, showInterval: Bool, hideTimes: Bool, overrideTimeZone: TimeZone? = nil) -> String {
        let intervalString: String
        if showInterval {
            intervalString = "  -  \(Int(duration)) sec"
        } else {
            intervalString = ""
        }
        let dateFormatter: DateFormatter
        if let overrideTimeZone {
            let df = hideTimes ? Self.dateOnlyFormatter : Self.dateFormatter
            df.timeZone = overrideTimeZone
            dateFormatter = df
        } else {
            dateFormatter = hideTimes ? Self.dateOnlyFormatter : Self.dateFormatter
        }
        let timeFormatter: DateFormatter
        if let overrideTimeZone {
            let df = Self.timeFormatter
            df.timeZone = overrideTimeZone
            timeFormatter = df
        } else {
            timeFormatter = Self.timeFormatter
        }
        if showStartDate {
            if Calendar.current.isDate(start, inSameDayAs: end) {
                return "\(trimTZ(string: dateFormatter.string(from: start))) - \(timeFormatter.string(from: end))\(intervalString)"
            } else {
                return "\(trimTZ(string: dateFormatter.string(from: start))) - \(dateFormatter.string(from: end))\(intervalString)"
            }
        } else {
            if Calendar.current.isDate(start, inSameDayAs: end) {
                return "\(trimTZ(string: timeFormatter.string(from: start))) - \(timeFormatter.string(from: end))\(intervalString)"
            } else {
                return "\(trimTZ(string: timeFormatter.string(from: start))) - \(dateFormatter.string(from: end))\(intervalString)"
            }
        }
        func trimTZ(string: String) -> String {
            guard !hideTimes else {
                return string
            }
            let pieces = string.components(separatedBy: " ")
            return pieces.dropLast().joined(separator: " ")
        }
    }
    
    var dateString: DateString {
        return DateInterval.dateStringFormatter.string(from: start)
    }
    
    func padInterval(before: TimeInterval, after: TimeInterval) -> DateInterval {
        return .init(start: start.addingTimeInterval(-before), end: end.addingTimeInterval(after))
    }
}

public extension Array where Element == DateInterval {
    
    func hasOverlaps() -> Bool {
        return !zip(self, self.dropFirst()).allSatisfy({ $0.0.end <= $0.1.start })
    }
    
    func overlappingIntervals(printToConsole: Bool) -> [(Int, Int)] {
        let hasOverlaps = hasOverlaps()
        if hasOverlaps {
            let dateFormatter = DateFormatter()
            dateFormatter.dateFormat = "yyyy-MM-dd HH:mm:ss.SSS ZZZ"
            if printToConsole {
                print("DateInterval array contains overlaps (only showing consecutive sample overlap, more may exist if a sample has a long duration and overlaps multiple)")
            }
            var overlaps = [(Int, Int)]()
            for idx in 1..<count {
                let first = self[idx - 1]
                let second = self[idx]
                if first.end > second.start {
                    if printToConsole {
                        print("[\(idx - 1)] : \(dateFormatter.string(from: first.start)) - \(dateFormatter.string(from: first.end))")
                        print("[\(idx)] : \(dateFormatter.string(from: second.start)) - \(dateFormatter.string(from: second.end))")
                        print("-------")
                    }
                    overlaps.append((idx - 1, idx))
                }
            }
            return overlaps
        } else {
            return []
        }
    }
    
    func groupedByDateDay(offset: UTCOffset?, splitIntervalsSpanningMultipleDays: Bool) -> [DateDay: [DateInterval]] {
        let output = NSMutableDictionary()  // [DateDay: [DateInterval]]()
        let calendar: Calendar
        if let offset {
            var c = Calendar.current
            c.timeZone = TimeZone(secondsFromGMT: Int(offset.secondsFromGMT))!
            calendar = c
        } else {
            calendar = .current
        }
        for interval in self.sorted() {
            let startDay = DateDay(date: interval.start)
            let endDay = DateDay(date: interval.end)
            let startDayArray: NSMutableArray
            if let array = output[startDay] as? NSMutableArray {
                startDayArray = array
            } else {
                startDayArray = NSMutableArray()
                output[startDay] = startDayArray
            }
            if splitIntervalsSpanningMultipleDays, startDay != endDay {
                let startInterval = DateInterval(start: interval.start, end: calendar.startOfDay(for: interval.end))
                let endInterval = DateInterval(start: calendar.startOfDay(for: interval.end), end: interval.end)
                startDayArray.add(startInterval)
                if let array = output[endDay] as? NSMutableArray {
                    array.add(endInterval)
                } else {
                    let array = NSMutableArray()
                    array.add(endInterval)
                    output[endDay] = array
                }
            } else {
                startDayArray.add(interval)
            }
        }
        return output as! [DateDay: [DateInterval]]
    }
}

public extension DateFormatter {
    static let shortDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .short
        return df
    }()
}

public struct DateDay: Codable, Hashable, Comparable, Sendable, Identifiable {
    
    public let year: Int
    public let month: Int
    public let day: Int
    
    static let epoch = Date(timeIntervalSince1970: 0)  // January 1, 1970
    
    /// Create a simple DateDay from a string
    /// - Parameter string: e.g., 2024-08-07
    public init?(string: String) {
        let pieces = string.components(separatedBy: "-")
        guard pieces.count == 3,
              let year = Int(pieces[0]),
              let month = Int(pieces[1]),
              let day = Int(pieces[2])
        else {
            return nil
        }
        self.year = year
        self.month = month
        self.day = day
    }
    
    public init(date: Date, calendar: Calendar = .current) {
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        self.year = dateComponents.year!
        self.month = dateComponents.month!
        self.day = dateComponents.day!
    }
    
    public init(dayNumber: Int) {
        let components = DateComponents(day: dayNumber, hour: 12)
        let date = Calendar.current.date(byAdding: components, to: Self.epoch)!
        self.init(date: date)
    }
    
    public init(year: Int, month: Int, day: Int) {
        self.year = year
        self.month = month
        self.day = day
    }
    
    public var string: String {
        let monthComp = (month < 10) ? "0\(month)" : "\(month)"
        let dayComp = (day < 10) ? "0\(day)" : "\(day)"
        return "\(year)-\(monthComp)-\(dayComp)"
    }
    
    public var date: Date {
        let dateComponents = DateComponents(calendar: .current, year: year, month: month, day: day, hour: 12)
        return Calendar.current.date(from: dateComponents)!
    }
    
    public var id: String {
        return "\(year)|\(month)|\(day)"
    }
    
    public var dayNumber: Int {
        return Calendar.current.dateComponents([.day], from: Self.epoch, to: date).day!
    }
    
    public static var today: DateDay {
        return DateDay(date: Date())
    }
    
    public static func < (lhs: DateDay, rhs: DateDay) -> Bool {
        if lhs.year != rhs.year {
            return lhs.year < rhs.year
        } else if lhs.month != rhs.month {
            return lhs.month < rhs.month
        } else {
            return lhs.day < rhs.day
        }
    }
    
    public func offsetByDays(_ days: Int) -> DateDay {
        return DateDay(dayNumber: dayNumber + days)
    }
    
    public static func + (lhs: DateDay, rhs: Int) -> DateDay {
        return lhs.offsetByDays(rhs)
    }
    
    public static func - (lhs: DateDay, rhs: Int) -> DateDay {
        return lhs.offsetByDays(-rhs)
    }
    
    public static func - (lhs: DateDay, rhs: DateDay) -> Int {
        return lhs.dayNumber - rhs.dayNumber
    }
    
    public var lastDateDayOfMonth: DateDay {
        let date = self.date
        let range = Calendar.current.range(of: .day, in: .month, for: date)!
        return .init(date: Calendar.current.date(bySetting: .day, value: range.count, of: date)!)
    }
    
    public var weekday: Int {
        return Calendar.current.component(.weekday, from: date)
    }
}

public struct UTCOffset: Codable, Sendable {
    public let hours: Int
    public let minutes: UInt
    public let seconds: UInt
    
    public init?(string: String) {
        let pieces = string.components(separatedBy: ":")
        guard pieces.count == 3,
              let hours = Int(pieces[0]),
              let minutes = UInt(pieces[1]),
              let seconds = UInt(pieces[2])
        else {
            return nil
        }
        self.hours = hours
        self.minutes = minutes
        self.seconds = seconds
    }
    
    public init(secondsFromGMT: Int) {
        self.hours = secondsFromGMT / (60 * 60)
        self.minutes = UInt((abs(secondsFromGMT) % (60 * 60)) / 60)
        self.seconds = UInt((abs(secondsFromGMT) % (60 * 60)) % 60)
    }
    
    public var string: String {
        let absHours = (abs(hours) < 10) ? "0\(abs(hours))" : "\(abs(hours))"
        let hoursComp = ((hours < 0) ? "-" : "") + absHours
        let minutesComp = (minutes < 10) ? "0\(minutes)" : "\(minutes)"
        let secondsComp = (seconds < 10) ? "0\(seconds)" : "\(seconds)"
        return "\(hoursComp):\(minutesComp):\(secondsComp)"
    }
    
    public var secondsFromGMT: Int {
        return (hours * (60 * 60)) + Int(minutes * 60) + Int(seconds)
    }
}
