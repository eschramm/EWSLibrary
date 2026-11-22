//
//  DateDayTests.swift
//
//  DateDay's arithmetic is integer math (no Calendar). These check it against Foundation's
//  Gregorian calendar, pinned to UTC, for every day from 1900 through 2100.
//

import Foundation
import Testing
@testable import EWSLibrary

struct DateDayTests {
    static let utc: Calendar = {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "UTC")!
        return calendar
    }()

    /// The day `n` days after 1970-01-01, as the calendar names it.
    static func calendarDay(_ n: Int) -> (day: DateDay, weekday: Int, lastDay: Int) {
        let date = Date(timeIntervalSince1970: TimeInterval(n) * 86_400)
        let parts = utc.dateComponents([.year, .month, .day, .weekday], from: date)
        let lastDay = utc.range(of: .day, in: .month, for: date)!.count
        return (DateDay(year: parts.year!, month: parts.month!, day: parts.day!), parts.weekday!, lastDay)
    }

    static func calendarDayNumber(_ year: Int, _ month: Int, _ day: Int) -> Int {
        let date = utc.date(from: DateComponents(year: year, month: month, day: day))!
        return Int((date.timeIntervalSince1970 / 86_400).rounded(.down))
    }

    @Test func everyDayFrom1900Through2100MatchesTheCalendar() {
        let first = Self.calendarDayNumber(1900, 1, 1), last = Self.calendarDayNumber(2100, 12, 31)
        #expect(DateDay(year: 1970, month: 1, day: 1).dayNumber == 0)
        var previous: DateDay?
        for n in first...last {
            let expected = Self.calendarDay(n)
            let day = DateDay(dayNumber: n)
            guard day == expected.day else {
                Issue.record("day \(n): \(day.string), the calendar says \(expected.day.string)")
                return
            }
            #expect(day.dayNumber == n, "\(day.string)")
            #expect(day.weekday == expected.weekday, "\(day.string)")
            #expect(day.lastDateDayOfMonth == DateDay(year: day.year, month: day.month, day: expected.lastDay), "\(day.string)")
            #expect(DateDay(string: day.string) == day)
            if let previous {
                #expect(previous < day)
                #expect(previous + 1 == day)
                #expect(day - 1 == previous)
                #expect(day - previous == 1)
            }
            previous = day
        }
    }

    @Test func offsetsAcrossMonthsYearsAndLeapDays() {
        let cases: [(String, Int, String)] = [
            ("2026-01-31", 1, "2026-02-01"),
            ("2024-02-28", 1, "2024-02-29"),
            ("2024-02-29", 1, "2024-03-01"),
            ("2023-02-28", 1, "2023-03-01"),
            ("2000-02-28", 1, "2000-02-29"),
            ("1900-02-28", 1, "1900-03-01"),
            ("2026-12-31", 1, "2027-01-01"),
            ("2027-01-01", -1, "2026-12-31"),
            ("2026-11-21", 365, "2027-11-21"),
            ("2026-11-21", -3650, "2016-11-23"),
            ("1969-12-31", 1, "1970-01-01"),
        ]
        for (start, days, end) in cases {
            #expect(DateDay(string: start)!.offsetByDays(days) == DateDay(string: end)!, "\(start) + \(days)")
            #expect(DateDay(string: end)! - DateDay(string: start)! == days, "\(end) - \(start)")
        }
    }

    /// `init(string:)` and `init(year:month:day:)` take anything; the arithmetic rolls an
    /// out-of-range month or day over, as the calendar does.
    @Test func outOfRangeDatesRollOverLikeTheCalendar() {
        let cases = [(2026, 2, 30), (2026, 13, 1), (2026, 0, 15), (2026, 3, 0), (2025, 1, 400),
                     (2026, -1, 1), (2026, 25, -3), (2024, 2, 29), (2023, 2, 29), (2026, 12, 32)]
        for (year, month, day) in cases {
            let given = DateDay(year: year, month: month, day: day)
            let expected = Self.calendarDayNumber(year, month, day)
            #expect(given.dayNumber == expected, "\(year)-\(month)-\(day)")
            #expect(given.offsetByDays(0) == Self.calendarDay(expected).day, "\(year)-\(month)-\(day)")
        }
    }

    /// Where a day meets a moment, the calendar is still used: in this process's time zone
    /// (`TZ=Asia/Tokyo swift test --filter DateDayTests` tries another). A day the zone skipped,
    /// as Kiribati skipped 1994-12-31 crossing the date line, has no moment and lands on the next.
    @Test func daysAndMomentsRoundTripInThisTimeZone() {
        let first = Self.calendarDayNumber(1990, 1, 1), last = Self.calendarDayNumber(2060, 12, 31)
        var skipped = 0
        for n in first...last {
            let day = DateDay(dayNumber: n)
            let back = DateDay(date: day.date)
            if back == day + 1 { skipped += 1; continue }
            guard back == day else {
                Issue.record("\(day.string) came back as \(back.string) in \(TimeZone.current.identifier)")
                return
            }
        }
        #expect(skipped <= 2)
    }
}
