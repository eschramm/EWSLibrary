//
//  Duration.swift
//  EWSLibrary
//
//  Created by Eric Schramm on 10/11/25.
//

import Foundation

public extension TimeInterval {
    
    internal static let lastModFormatterLessThan5Minutes: DateComponentsFormatter = {
        let f = DateComponentsFormatter()
        f.unitsStyle = .abbreviated
        f.allowedUnits = [.minute, .second]
        f.zeroFormattingBehavior = .dropAll
        return f
    }()
    
    internal static let lastModFormatterLessThanWeek: DateComponentsFormatter = {
        let f = DateComponentsFormatter()
        f.unitsStyle = .abbreviated
        f.allowedUnits = [.day, .hour, .minute]
        f.zeroFormattingBehavior = .dropAll
        return f
    }()
    
    internal static let lastModFormatterLessThanYear: DateComponentsFormatter = {
        let f = DateComponentsFormatter()
        f.unitsStyle = .abbreviated
        f.allowedUnits = [.month, .day]
        f.zeroFormattingBehavior = .dropAll
        return f
    }()
    
    internal static let lastModFormatterMoreThanYear: DateComponentsFormatter = {
        let f = DateComponentsFormatter()
        f.unitsStyle = .abbreviated
        f.allowedUnits = [.year, .month, .day]
        f.zeroFormattingBehavior = .dropAll
        return f
    }()
    
    func formattedEWS() -> String {
        let absSelf = abs(self)
        let negative = (self < 0) ? "-" : ""
        guard absSelf != 0 else {
            return "0 sec"
        }
        guard absSelf > 0.1 else {
            return "\(negative)\((self * 1000).formatted()) ms"
        }
        guard self >= 120 else {
            return "\(self.formatted()) sec"
        }
        let floorsDict: [Double   : DateComponentsFormatter] = [
            (60 * 5)              : Self.lastModFormatterLessThan5Minutes,
            (60 * 60 * 24 * 7)    : Self.lastModFormatterLessThanWeek,
            (60 * 60 * 24 * 365)  : Self.lastModFormatterLessThanYear,
            (60 * 60 * 24 * 1000) : Self.lastModFormatterMoreThanYear
        ]
        let text = itemForValueInRange(dict: floorsDict).string(from: self)
        return (text == nil) ? "<error>" : "\(negative)\(text!)"
    }
}

public extension Double {
    func itemForValueInRange<T>(dict: [Double : T]) -> T {
        guard !dict.isEmpty else {
            fatalError("Empty dictionary")
        }
        let sortedFloors = dict.keys.sorted()
        for valueFloor in sortedFloors {
            if self < valueFloor {
                return dict[valueFloor]!
            }
        }
        return dict[sortedFloors.last!]!
    }
}

public extension Date {
    static func lastModifiedString(since date: Date) -> String {
        let now = Date()
        let distance = date.distance(to: now)
        if distance <= 60 {
            return "just now"
        }
        
        let text: String?
        switch distance {
        case 0...60                 : text = "just now"
        case 60...604_800           : text = TimeInterval.lastModFormatterLessThanWeek.string(from: date, to: now)
        case 86_400...31_536_000    : text = TimeInterval.lastModFormatterLessThanYear.string(from: date, to: now)
        default                     : text = TimeInterval.lastModFormatterMoreThanYear.string(from: date, to: now)
        }
        
        return (text == nil) ? "<error>" : "\(text!) ago"
    }
}
