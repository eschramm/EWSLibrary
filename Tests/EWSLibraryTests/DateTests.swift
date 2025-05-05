//
//  DateTests.swift
//  
//
//  Created by Eric Schramm on 11/29/23.
//

import XCTest

extension Date {
    func bruteForceContainedInsideIntervals(intervals: [DateInterval]) -> Bool {
        var iterations = 0
        
        /*
        defer {
            print("Iterations 🐢: \(iterations)")
        }
         */
        
        for interval in intervals {
            iterations += 1
            if interval.contains(self) {
                return true
            }
        }
        return false
    }
    
    func bruteForceNextIndex(for sortedDates: [Date]) -> Int {
        var iterations = 0
        for date in sortedDates {
            iterations += 1
            if self < date {
                return iterations - 1
            }
        }
        return iterations
    }
}

final class DateBinarySearchTests: XCTestCase {
    var df = DateFormatter()
    var dates = [Date]()
    
    override func setUpWithError() throws {
        
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        dates = [
            df.date(from: "2023-01-01 00:00:00")!,
            df.date(from: "2023-01-03 00:00:00")!,
            df.date(from: "2023-01-05 00:00:00")!,
            df.date(from: "2023-01-07 00:00:00")!,
            df.date(from: "2023-01-09 00:00:00")!,
            df.date(from: "2023-01-11 00:00:00")!,
            df.date(from: "2023-01-13 00:00:00")!,
            df.date(from: "2023-01-15 00:00:00")!,
            df.date(from: "2023-01-17 00:00:00")!,
            df.date(from: "2023-01-19 00:00:00")!,
            df.date(from: "2023-01-21 00:00:00")!,
            df.date(from: "2023-01-23 00:00:00")!,
            df.date(from: "2023-01-25 00:00:00")!,
            df.date(from: "2023-01-27 00:00:00")!,
            df.date(from: "2023-01-29 00:00:00")!,
            df.date(from: "2023-01-31 00:00:00")!,
            df.date(from: "2023-03-01 00:00:00")!,
            df.date(from: "2023-03-03 00:00:00")!,
            df.date(from: "2023-03-05 00:00:00")!,
            df.date(from: "2023-03-07 00:00:00")!,
        ]
    }
    
    func testBinarySearchChecker() throws {
        try testBinaryDateSearch(for: df.date(from: "2023-01-01 12:00:00")!, expectation: 1)
        try testBinaryDateSearch(for: df.date(from: "2023-01-29 12:00:00")!, expectation: 15)
        try testBinaryDateSearch(for: df.date(from: "2023-01-02 12:00:00")!, expectation: 1)
        try testBinaryDateSearch(for: df.date(from: "2022-01-02 12:00:00")!, expectation: 0)
        try testBinaryDateSearch(for: df.date(from: "2024-01-02 12:00:00")!, expectation: 20)
        try testBinaryDateSearch(for: df.date(from: "2023-01-01 00:00:00")!, expectation: 1)  // equal to a date in array, still return the next item
    }
    
    func testBinaryDateSearch(for date: Date, expectation: Int) throws {
        XCTAssertEqual(date.nextIndex(for: dates).nextIndex, expectation)
        XCTAssertEqual(date.bruteForceNextIndex(for: dates), expectation)
    }
    
    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        let datesToEvaluate: [Date] = [
            df.date(from: "2023-01-01 12:00:00")!,
            df.date(from: "2023-01-02 12:00:00")!,
            df.date(from: "2023-01-03 12:00:00")!,
            df.date(from: "2023-01-04 12:00:00")!,
            df.date(from: "2023-01-05 12:00:00")!,
            df.date(from: "2023-01-06 12:00:00")!,
            df.date(from: "2023-02-01 12:00:00")!,
            df.date(from: "2023-03-01 12:00:00")!,
            df.date(from: "2023-03-02 12:00:00")!,
            df.date(from: "2023-03-03 12:00:00")!,
            df.date(from: "2023-03-04 12:00:00")!,
            df.date(from: "2023-03-05 12:00:00")!,
            df.date(from: "2023-03-06 12:00:00")!,
            df.date(from: "2022-01-01 12:00:00")!,
            df.date(from: "2024-01-01 12:00:00")!,
            df.date(from: "2023-01-02 00:00:00")!,
            df.date(from: "2023-01-03 00:00:00")!,
            df.date(from: "2023-01-28 12:00:00")!,
            df.date(from: "2023-01-29 12:00:00")!,
        ]
        measure {
            for _ in 0..<1000 {
                for date in datesToEvaluate {
                    _ = date.nextIndex(for: dates)
                }
            }
        }
    }
    
    func testBruteForcePerformanceExample() throws {
        // This is an example of a performance test case.
        let datesToEvaluate: [Date] = [
            df.date(from: "2023-01-01 12:00:00")!,
            df.date(from: "2023-01-02 12:00:00")!,
            df.date(from: "2023-01-03 12:00:00")!,
            df.date(from: "2023-01-04 12:00:00")!,
            df.date(from: "2023-01-05 12:00:00")!,
            df.date(from: "2023-01-06 12:00:00")!,
            df.date(from: "2023-02-01 12:00:00")!,
            df.date(from: "2023-03-01 12:00:00")!,
            df.date(from: "2023-03-02 12:00:00")!,
            df.date(from: "2023-03-03 12:00:00")!,
            df.date(from: "2023-03-04 12:00:00")!,
            df.date(from: "2023-03-05 12:00:00")!,
            df.date(from: "2023-03-06 12:00:00")!,
            df.date(from: "2022-01-01 12:00:00")!,
            df.date(from: "2024-01-01 12:00:00")!,
            df.date(from: "2023-01-02 00:00:00")!,
            df.date(from: "2023-01-03 00:00:00")!,
            df.date(from: "2023-01-28 12:00:00")!,
            df.date(from: "2023-01-29 12:00:00")!,
        ]
        measure {
            for _ in 0..<1000 {
                for date in datesToEvaluate {
                    _ = date.bruteForceNextIndex(for: dates)
                }
            }
        }
    }
}

final class DateIntervalSearchTests: XCTestCase {
    
    var df = DateFormatter()
    var intervals = [DateInterval]()

    override func setUpWithError() throws {
        
        df.dateFormat = "yyyy-MM-dd HH:mm:ss"
        
        intervals = [
            .init(start: df.date(from: "2023-01-01 00:00:00")!, end: df.date(from: "2023-01-02 00:00:00")!),
            .init(start: df.date(from: "2023-01-03 00:00:00")!, end: df.date(from: "2023-01-04 00:00:00")!),
            .init(start: df.date(from: "2023-01-05 00:00:00")!, end: df.date(from: "2023-01-06 00:00:00")!),
            .init(start: df.date(from: "2023-01-07 00:00:00")!, end: df.date(from: "2023-01-08 00:00:00")!),
            .init(start: df.date(from: "2023-01-09 00:00:00")!, end: df.date(from: "2023-01-10 00:00:00")!),
            .init(start: df.date(from: "2023-01-11 00:00:00")!, end: df.date(from: "2023-01-12 00:00:00")!),
            .init(start: df.date(from: "2023-01-13 00:00:00")!, end: df.date(from: "2023-01-14 00:00:00")!),
            .init(start: df.date(from: "2023-01-15 00:00:00")!, end: df.date(from: "2023-01-16 00:00:00")!),
            .init(start: df.date(from: "2023-01-17 00:00:00")!, end: df.date(from: "2023-01-18 00:00:00")!),
            .init(start: df.date(from: "2023-01-19 00:00:00")!, end: df.date(from: "2023-01-20 00:00:00")!),
            .init(start: df.date(from: "2023-01-21 00:00:00")!, end: df.date(from: "2023-01-22 00:00:00")!),
            .init(start: df.date(from: "2023-01-23 00:00:00")!, end: df.date(from: "2023-01-24 00:00:00")!),
            .init(start: df.date(from: "2023-01-25 00:00:00")!, end: df.date(from: "2023-01-26 00:00:00")!),
            .init(start: df.date(from: "2023-01-27 00:00:00")!, end: df.date(from: "2023-01-28 00:00:00")!),
            .init(start: df.date(from: "2023-01-29 00:00:00")!, end: df.date(from: "2023-01-30 00:00:00")!),
            .init(start: df.date(from: "2023-01-31 00:00:00")!, end: df.date(from: "2023-02-01 00:00:00")!),
            .init(start: df.date(from: "2023-03-01 00:00:00")!, end: df.date(from: "2023-03-02 00:00:00")!),
            .init(start: df.date(from: "2023-03-03 00:00:00")!, end: df.date(from: "2023-03-04 00:00:00")!),
            .init(start: df.date(from: "2023-03-05 00:00:00")!, end: df.date(from: "2023-03-06 00:00:00")!),
            .init(start: df.date(from: "2023-03-07 00:00:00")!, end: df.date(from: "2023-03-08 00:00:00")!),
        ]
    }

    func testIntervalChecker() throws {
        try testInterval(for: df.date(from: "2023-01-01 12:00:00")!, expectation: true)
        try testInterval(for: df.date(from: "2023-01-29 12:00:00")!, expectation: true)
        try testInterval(for: df.date(from: "2023-01-02 12:00:00")!, expectation: false)
        try testInterval(for: df.date(from: "2022-01-02 12:00:00")!, expectation: false)
        try testInterval(for: df.date(from: "2024-01-02 12:00:00")!, expectation: false)
        try testInterval(for: df.date(from: "2023-01-01 00:00:00")!, expectation: true)  // equal to edge of end of interval - start
        try testInterval(for: df.date(from: "2023-01-02 00:00:00")!, expectation: true)  // equal to edge of end of interval - end
    }
    
    func testInterval(for date: Date, expectation: Bool) throws {
        XCTAssertEqual(date.containedInsideIntervals(sortedIntervals: intervals).0, expectation)
        XCTAssertEqual(date.bruteForceContainedInsideIntervals(intervals: intervals), expectation)
    }

    func testPerformanceExample() throws {
        // This is an example of a performance test case.
        let datesToEvaluate: [Date] = [
            df.date(from: "2023-01-01 12:00:00")!,
            df.date(from: "2023-01-02 12:00:00")!,
            df.date(from: "2023-01-03 12:00:00")!,
            df.date(from: "2023-01-04 12:00:00")!,
            df.date(from: "2023-01-05 12:00:00")!,
            df.date(from: "2023-01-06 12:00:00")!,
            df.date(from: "2023-02-01 12:00:00")!,
            df.date(from: "2023-03-01 12:00:00")!,
            df.date(from: "2023-03-02 12:00:00")!,
            df.date(from: "2023-03-03 12:00:00")!,
            df.date(from: "2023-03-04 12:00:00")!,
            df.date(from: "2023-03-05 12:00:00")!,
            df.date(from: "2023-03-06 12:00:00")!,
            df.date(from: "2022-01-01 12:00:00")!,
            df.date(from: "2024-01-01 12:00:00")!,
            df.date(from: "2023-01-02 00:00:00")!,
            df.date(from: "2023-01-03 00:00:00")!,
            df.date(from: "2023-01-28 12:00:00")!,
            df.date(from: "2023-01-29 12:00:00")!,
        ]
        measure {
            for _ in 0..<1000 {
                for date in datesToEvaluate {
                    _ = date.containedInsideIntervals(sortedIntervals: intervals)
                }
            }
        }
    }
    
    func testBruteForcePerformanceExample() throws {
        // This is an example of a performance test case.
        let datesToEvaluate: [Date] = [
            df.date(from: "2023-01-01 12:00:00")!,
            df.date(from: "2023-01-02 12:00:00")!,
            df.date(from: "2023-01-03 12:00:00")!,
            df.date(from: "2023-01-04 12:00:00")!,
            df.date(from: "2023-01-05 12:00:00")!,
            df.date(from: "2023-01-06 12:00:00")!,
            df.date(from: "2023-02-01 12:00:00")!,
            df.date(from: "2023-03-01 12:00:00")!,
            df.date(from: "2023-03-02 12:00:00")!,
            df.date(from: "2023-03-03 12:00:00")!,
            df.date(from: "2023-03-04 12:00:00")!,
            df.date(from: "2023-03-05 12:00:00")!,
            df.date(from: "2023-03-06 12:00:00")!,
            df.date(from: "2022-01-01 12:00:00")!,
            df.date(from: "2024-01-01 12:00:00")!,
            df.date(from: "2023-01-02 00:00:00")!,
            df.date(from: "2023-01-03 00:00:00")!,
            df.date(from: "2023-01-28 12:00:00")!,
            df.date(from: "2023-01-29 12:00:00")!,
            df.date(from: "2023-01-01 12:00:00")!,
            df.date(from: "2023-01-02 12:00:00")!,
            df.date(from: "2023-01-03 12:00:00")!,
            df.date(from: "2023-01-04 12:00:00")!,
            df.date(from: "2023-01-05 12:00:00")!,
            df.date(from: "2023-01-06 12:00:00")!,
            df.date(from: "2023-02-01 12:00:00")!,
            df.date(from: "2023-03-01 12:00:00")!,
            df.date(from: "2023-03-02 12:00:00")!,
            df.date(from: "2023-03-03 12:00:00")!,
            df.date(from: "2023-03-04 12:00:00")!,
            df.date(from: "2023-03-05 12:00:00")!,
            df.date(from: "2023-03-06 12:00:00")!,
            df.date(from: "2022-01-01 12:00:00")!,
            df.date(from: "2024-01-01 12:00:00")!,
            df.date(from: "2023-01-02 00:00:00")!,
            df.date(from: "2023-01-03 00:00:00")!,
            df.date(from: "2023-01-28 12:00:00")!,
            df.date(from: "2023-01-29 12:00:00")!,
        ]
        measure {
            for _ in 0..<1000 {
                for date in datesToEvaluate {
                    _ = date.bruteForceContainedInsideIntervals(intervals: intervals)
                }
            }
        }
    }
}

import Testing

struct DateTests2 {
    @Test func previousIndex() {
        let indexDate = Date()
        let dates = [
            indexDate,                          // 0
            indexDate.addingTimeInterval(100),  // 1
            indexDate.addingTimeInterval(200),  // 2
            indexDate.addingTimeInterval(300),  // 3
            indexDate.addingTimeInterval(400)   // 4
        ]
        
        #expect(indexDate.addingTimeInterval(250).previousIndex(for: dates) == 2)
        #expect(indexDate.addingTimeInterval(50).previousIndex(for: dates) == 0)
        
        // edges
        #expect(indexDate.previousIndex(for: dates) == 0, "equals")
        #expect(indexDate.addingTimeInterval(-10).previousIndex(for: dates) == nil, "before any date in array")
        #expect(indexDate.addingTimeInterval(500).previousIndex(for: dates) == 4, "after all dates in array")
    }
}

