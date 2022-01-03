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
}

public extension DateFormatter {
    static let shortDateFormatter: DateFormatter = {
        let df = DateFormatter()
        df.dateStyle = .short
        return df
    }()
}
