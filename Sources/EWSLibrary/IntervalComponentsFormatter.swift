//
//  IntervalComponentsFormatter.swift
//  EWSLibrary
//

import Foundation

#if canImport(Darwin)
typealias IntervalComponentsFormatter = DateComponentsFormatter
#else
/// Stand-in for the slice of `DateComponentsFormatter` this library uses, which
/// swift-corelibs-foundation does not provide. Output is always abbreviated English
/// ("3d 4h 12m") with zero-valued units dropped. Like the real formatter, an interval is
/// measured as calendar components counted forward from the reference date (2001-01-01 UTC).
final class IntervalComponentsFormatter: @unchecked Sendable /* configured once, then read-only */ {
    enum UnitsStyle { case abbreviated }
    enum ZeroFormattingBehavior { case dropAll }

    var unitsStyle: UnitsStyle = .abbreviated
    var allowedUnits: NSCalendar.Unit = [.day, .hour, .minute, .second]
    var zeroFormattingBehavior: ZeroFormattingBehavior = .dropAll

    private static let units: [(unit: NSCalendar.Unit, component: Calendar.Component, suffix: String)] = [
        (.year, .year, "y"),
        (.month, .month, "mo"),
        (.day, .day, "d"),
        (.hour, .hour, "h"),
        (.minute, .minute, "m"),
        (.second, .second, "s")
    ]

    private static let calendar: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }()

    func string(from interval: TimeInterval) -> String? {
        guard interval.isFinite else { return nil }
        let allowed = Self.units.filter { allowedUnits.contains($0.unit) }
        guard let smallest = allowed.last else { return nil }
        let start = Date(timeIntervalSinceReferenceDate: 0)
        let end = Date(timeIntervalSinceReferenceDate: abs(interval).rounded(.down))
        let components = Self.calendar.dateComponents(Set(allowed.map(\.component)), from: start, to: end)
        let parts: [String] = allowed.compactMap { entry in
            guard let count = components.value(for: entry.component), count > 0 else { return nil }
            return "\(count)\(entry.suffix)"
        }
        return parts.isEmpty ? "0\(smallest.suffix)" : parts.joined(separator: " ")
    }

    func string(from start: Date, to end: Date) -> String? {
        string(from: end.timeIntervalSince(start))
    }
}
#endif
