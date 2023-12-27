//
//  File.swift
//  
//
//  Created by Eric Schramm on 1/3/22.
//

import Foundation

public extension Date {
    
    func truncateToNoon(calendar: Calendar = .current) -> Date {
        return calendar.date(bySettingHour: 12, minute: 0, second: 0, of: self)!
    }
    
    func truncateToMidnight(calendar: Calendar = .current) -> Date? {
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
                print("DateInterval array contains overlaps")
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
