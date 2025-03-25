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
    
    func debugDescription(showStartDate: Bool, showInterval: Bool) -> String {
        let intervalString: String
        if showInterval {
            intervalString = "  -  \(Int(duration)) sec"
        } else {
            intervalString = ""
        }
        if showStartDate {
            if Calendar.current.isDate(start, inSameDayAs: end) {
                return "\(trimTZ(string: DateInterval.dateFormatter.string(from: start))) - \(DateInterval.timeFormatter.string(from: end))\(intervalString)"
            } else {
                return "\(trimTZ(string: DateInterval.dateFormatter.string(from: start))) - \(DateInterval.dateFormatter.string(from: end))\(intervalString)"
            }
        } else {
            if Calendar.current.isDate(start, inSameDayAs: end) {
                return "\(trimTZ(string: DateInterval.timeFormatter.string(from: start))) - \(DateInterval.timeFormatter.string(from: end))\(intervalString)"
            } else {
                return "\(trimTZ(string: DateInterval.timeFormatter.string(from: start))) - \(DateInterval.dateFormatter.string(from: end))\(intervalString)"
            }
        }
        func trimTZ(string: String) -> String {
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
}

public extension DateFormatter {
    static let shortDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .short
        return df
    }()
}

public struct DateDay: Codable, Hashable, Comparable, Sendable {
    
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
    
    public init(date: Date, calendar: Calendar) {
        let dateComponents = calendar.dateComponents([.year, .month, .day], from: date)
        self.year = dateComponents.year!
        self.month = dateComponents.month!
        self.day = dateComponents.day!
    }
    
    public var string: String {
        let monthComp = (month < 10) ? "0\(month)" : "\(month)"
        let dayComp = (day < 10) ? "0\(day)" : "\(day)"
        return "\(year)-\(monthComp)-\(dayComp)"
    }
    
    public func date(calendar: Calendar = .current) -> Date {
        let dateComponents = DateComponents(calendar: calendar, year: year, month: month, day: day)
        return calendar.date(from: dateComponents)!
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
    
    
    public var string: String {
        let absHours = (abs(hours) < 10) ? "0\(abs(hours))" : "\(abs(hours))"
        let hoursComp = ((hours < 0) ? "-" : "") + absHours
        let minutesComp = (minutes < 10) ? "0\(minutes)" : "\(minutes)"
        let secondsComp = (seconds < 10) ? "0\(seconds)" : "\(seconds)"
        return "\(hoursComp):\(minutesComp):\(secondsComp)"
    }
    
    public var secondsFromGMT: TimeInterval {
        return Double(hours * (60 * 60)) + Double(minutes * 60) + Double(seconds)
    }
}
