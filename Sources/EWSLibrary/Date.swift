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
            let df = DateFormatter()
            if hideTimes {
                df.dateStyle = .short
            } else {
                df.dateStyle = .short
                df.timeStyle = .long
            }
            df.timeZone = overrideTimeZone
            dateFormatter = df
        } else {
            dateFormatter = hideTimes ? Self.dateOnlyFormatter : Self.dateFormatter
        }
        let timeFormatter: DateFormatter
        if let overrideTimeZone {
            let df = DateFormatter()
            df.timeStyle = .long
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
    
    /// The day `dayNumber` days after 1970-01-01 (negative before it). Integer math, no Calendar.
    public init(dayNumber: Int) {
        let (year, month, day) = Self.civil(fromDayNumber: dayNumber)
        self.init(year: year, month: month, day: day)
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
    
    public func dateInCalendar(_ calendar: Calendar) -> Date {
        let dateComponents = DateComponents(calendar: calendar, year: year, month: month, day: day, hour: 12)
        return Calendar.current.date(from: dateComponents)!
    }
    
    public var id: String {
        return "\(year)|\(month)|\(day)"
    }
    
    /// Days since 1970-01-01, negative before it. An out-of-range month or day rolls over as
    /// Calendar does (2026-02-30 is 2026-03-02, month 13 is January of the next year).
    public var dayNumber: Int {
        let months = year * 12 + (month - 1)
        let (normalizedYear, normalizedMonth) = (Self.floorDivide(months, 12), months - Self.floorDivide(months, 12) * 12 + 1)
        return Self.dayNumber(year: normalizedYear, month: normalizedMonth, day: 1) + (day - 1)
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
        let normalized = offsetByDays(0)
        return .init(year: normalized.year, month: normalized.month, day: Self.daysInMonth(year: normalized.year, month: normalized.month))
    }
    
    /// 1 is Sunday through 7, Saturday, as Calendar's Gregorian `.weekday`.
    public var weekday: Int {
        let sinceThursday = (dayNumber % 7 + 7) % 7   // 1970-01-01 was a Thursday
        return (sinceThursday + 4) % 7 + 1
    }
    
    // Day arithmetic in plain integers (Howard Hinnant's days_from_civil and civil_from_days,
    // https://howardhinnant.github.io/date_algorithms.html): the proleptic Gregorian calendar,
    // exact for any year, with no Calendar, no time zone and no lock, so it costs nothing when
    // many threads do it at once. Calendar.current is shared and serializes its callers; the
    // arithmetic used to go through it four times for each `+ n`. (Foundation's Gregorian
    // calendar is Julian before 1582-10-15; these are Gregorian throughout.)
    
    static func floorDivide(_ a: Int, _ b: Int) -> Int {
        a >= 0 ? a / b : -((-a + b - 1) / b)
    }
    
    static func dayNumber(year: Int, month: Int, day: Int) -> Int {
        let y = month <= 2 ? year - 1 : year
        let era = floorDivide(y, 400)
        let yearOfEra = y - era * 400
        let dayOfYear = (153 * (month > 2 ? month - 3 : month + 9) + 2) / 5 + day - 1
        let dayOfEra = yearOfEra * 365 + yearOfEra / 4 - yearOfEra / 100 + dayOfYear
        return era * 146_097 + dayOfEra - 719_468
    }
    
    static func civil(fromDayNumber dayNumber: Int) -> (year: Int, month: Int, day: Int) {
        let z = dayNumber + 719_468
        let era = floorDivide(z, 146_097)
        let dayOfEra = z - era * 146_097
        let yearOfEra = (dayOfEra - dayOfEra / 1460 + dayOfEra / 36_524 - dayOfEra / 146_096) / 365
        let dayOfYear = dayOfEra - (365 * yearOfEra + yearOfEra / 4 - yearOfEra / 100)
        let shiftedMonth = (5 * dayOfYear + 2) / 153
        let day = dayOfYear - (153 * shiftedMonth + 2) / 5 + 1
        let month = shiftedMonth < 10 ? shiftedMonth + 3 : shiftedMonth - 9
        return (yearOfEra + era * 400 + (month <= 2 ? 1 : 0), month, day)
    }
    
    static func daysInMonth(year: Int, month: Int) -> Int {
        switch month {
        case 2: return (year % 4 == 0 && year % 100 != 0) || year % 400 == 0 ? 29 : 28
        case 4, 6, 9, 11: return 30
        default: return 31
        }
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
