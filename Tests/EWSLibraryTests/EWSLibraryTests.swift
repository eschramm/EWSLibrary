import XCTest
@testable import EWSLibrary

final class EWSLibraryTests: XCTestCase {
    
    #if os(macOS)
    func testShell() {
        let shell = Shell()
        XCTAssert(shell.outputOf(commandName: "echo", arguments: ["testing the shell"]) == "testing the shell\n")
    }
    #endif
    
    func realTruesRandomizationTrial(trueProbability: Double) -> Double {
        let trialCount = 10_000
        var trueCount = 0
        for _ in 0..<trialCount {
            if randomBool(withTrueProbability: trueProbability) {
                trueCount += 1
            }
        }
        return Double(trueCount) / Double(trialCount)
    }
    
    func testAlwaysRandomization() {
        let testRun = realTruesRandomizationTrial(trueProbability: 1)
        //XCTAssertLessThan(fabs(testRun - 1), 0.0000001)
        XCTAssertEqual(testRun, 1)
    }
    
    func testNeverRandomization() {
        let testRun = realTruesRandomizationTrial(trueProbability: 0)
        //XCTAssertLessThan(fabs(testRun - 0), 0.0000001)
        XCTAssertEqual(testRun, 0)
    }

    func testSometimesRandomization() {
        for probability in [0.25, 0.5, 0.75] {
            let testRun = realTruesRandomizationTrial(trueProbability: probability)
            XCTAssertLessThan(fabs(testRun - probability), 0.02)
        }
    }
    
    @available(macOS 13.0, *)
    func testAsyncTimer() async throws {
        let start = Date()
        let interval: Double = 1
        let allowedErrorInterval: TimeInterval = 0.5
        var firings = [Date]()
        print("Testing AsyncTimer - expected delay")
        let timer = AsyncTimer(interval: interval) {
            print("Timer fired")
            firings.append(Date())
        }
        await timer.start(fireNow: false)
        try await Task.sleep(for: .seconds(Int(interval) * 8))
        await timer.stop()
        let firingsAfterStop = firings.count
        XCTAssertGreaterThan(firings.count, 6)
        XCTAssertLessThan(firings.count, 10)
        var intervals = [TimeInterval]()
        intervals.append(start.distance(to: firings[0]) - interval)
        for n in 1..<firings.count {
            intervals.append(firings[n - 1].distance(to: firings[n]) - interval)
        }
        let stats = intervals.stats()
        stats.printAllStats(count: intervals.count, numberFormatter: nil)
        try await Task.sleep(for: .seconds(Int(interval) * 2))
        XCTAssertEqual(firings.count, firingsAfterStop, "AsyncTimer fired additional times after being stopped")
        XCTAssertEqual(intervals.filter({ abs($0) > allowedErrorInterval }).count, 0, "At least one of the intervals for the AsyncTimer exceeds expected error of \(allowedErrorInterval)")
        await timer.start(fireNow: true)
        try await Task.sleep(for: .seconds(Int(interval) * 3))
        XCTAssertGreaterThan(firings.count, firingsAfterStop + 2, "Async timer failed to make the initial and at least one firing after a restart")
    }

    #if os(macOS)
    static var allTests = [
        ("testShell", testShell),
        ("testAlwaysRandomization", testAlwaysRandomization),
        ("testNeverRandomization", testNeverRandomization),
        ("testSometimeRandomization", testSometimesRandomization)
    ]
    #elseif os(iOS)
    static var allTests = [
        ("testAlwaysRandomization", testAlwaysRandomization),
        ("testNeverRandomization", testNeverRandomization),
        ("testSometimeRandomization", testSometimesRandomization)
    ]
    #endif
}
