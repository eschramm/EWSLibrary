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
    
    func testAsyncTimer() async throws {
        let start = ProcessInfo.processInfo.systemUptime
        let interval: Double = 1
        let allowedErrorInterval: TimeInterval = 0.5
        var firings = [TimeInterval]()
        print("Testing AsyncTimer - expected delay")
        let timer = AsyncTimer(interval: interval) { _ in 
            print("Timer fired")
            firings.append(ProcessInfo.processInfo.systemUptime)
        }
        await timer.start(fireNow: false)
        try await Task.sleep(nanoseconds: interval.nanoSeconds * 8)
        await timer.stop()
        let firingsAfterStop = firings.count
        XCTAssertGreaterThan(firings.count, 6)
        XCTAssertLessThan(firings.count, 10)
        var intervals = [TimeInterval]()
        intervals.append(firings[0] - start - interval)
        for n in 1..<firings.count {
            intervals.append(firings[n] - firings[n - 1] - interval)
        }
        let stats = intervals.stats()
        stats.printAllStats(count: intervals.count, numberFormatter: nil)
        try await Task.sleep(nanoseconds: interval.nanoSeconds * 2)
        XCTAssertEqual(firings.count, firingsAfterStop, "AsyncTimer fired additional times after being stopped")
        XCTAssertEqual(intervals.filter({ abs($0) > allowedErrorInterval }).count, 0, "At least one of the intervals for the AsyncTimer exceeds expected error of \(allowedErrorInterval)")
        await timer.start(fireNow: true)
        try await Task.sleep(nanoseconds: interval.nanoSeconds * 3)
        XCTAssertGreaterThan(firings.count, firingsAfterStop + 2, "Async timer failed to make the initial and at least one firing after a restart")
    }
    
    func testASyncAtomicOperationWithOperation() async throws {
        let atomicQueue = AsyncAtomicOperationQueue()
        let allStart = ProcessInfo.processInfo.systemUptime
        var operatingIntervals = [(TimeInterval, TimeInterval)]()
        let scaling = 3_000_000
        print("enqueuing 1 - \(ProcessInfo.processInfo.systemUptime - allStart)")
        await atomicQueue.enqueueOperation(identifier: "1") {
            let start = ProcessInfo.processInfo.systemUptime
            print("Start Performing 1 - \(ProcessInfo.processInfo.systemUptime - allStart)")
            var p = 0
            for n in 0...scaling {
                p += n
            }
            print("Done Performing 1 : \(scaling) - \(ProcessInfo.processInfo.systemUptime - allStart)")
            operatingIntervals.append((start - allStart, ProcessInfo.processInfo.systemUptime - allStart))
        }
        print("enqueuing 2 - \(ProcessInfo.processInfo.systemUptime - allStart)")
        await atomicQueue.enqueueOperation(identifier: "2") {
            let start = ProcessInfo.processInfo.systemUptime
            print("Start Performing 2 - \(ProcessInfo.processInfo.systemUptime - allStart)")
            var p = 0
            for n in 0...Int(Double(scaling) * 0.25) {
                p += n
            }
            print("Done Performing 2 : \(Double(scaling) * 0.25) - \(ProcessInfo.processInfo.systemUptime - allStart)")
            operatingIntervals.append((start - allStart, ProcessInfo.processInfo.systemUptime - allStart))
        }
        print("enqueuing 3 - \(ProcessInfo.processInfo.systemUptime - allStart)")
        await atomicQueue.enqueueOperation(identifier: "3") {
            let start = ProcessInfo.processInfo.systemUptime
            print("Start Performing 3 - \(ProcessInfo.processInfo.systemUptime - allStart)")
            var p = 0
            for n in 0...Int(Double(scaling) * 0.4) {
                p += n
            }
            print("Done Performing 3 : \(Double(scaling) * 0.4) - \(ProcessInfo.processInfo.systemUptime - allStart)")
            operatingIntervals.append((start - allStart, ProcessInfo.processInfo.systemUptime - allStart))
        }
        print("enqueuing 4 - \(ProcessInfo.processInfo.systemUptime - allStart)")
        await atomicQueue.enqueueOperation(identifier: "4") {
            let start = ProcessInfo.processInfo.systemUptime
            print("Start Performing 4 - \(ProcessInfo.processInfo.systemUptime - allStart)")
            var p = 0
            for n in 0...Int(Double(scaling) * 0.1) {
                p += n
            }
            print("Done Performing 4 : \(Double(scaling) * 0.1) - \(ProcessInfo.processInfo.systemUptime - allStart)")
            operatingIntervals.append((start - allStart, ProcessInfo.processInfo.systemUptime - allStart))
        }
        print("enqueuing 5 - \(ProcessInfo.processInfo.systemUptime - allStart)")
        await atomicQueue.enqueueOperation(identifier: "5") {
            let start = ProcessInfo.processInfo.systemUptime
            print("Start Performing 5 - \(ProcessInfo.processInfo.systemUptime - allStart)")
            var p = 0
            for n in 0...Int(Double(scaling) * 0.05) {
                p += n
            }
            print("Done Performing 5 : \(Double(scaling) * 0.05) - \(ProcessInfo.processInfo.systemUptime - allStart)")
            operatingIntervals.append((start - allStart, ProcessInfo.processInfo.systemUptime - allStart))
        }
        print("enqueuing 6 - \(ProcessInfo.processInfo.systemUptime - allStart)")
        await atomicQueue.enqueueOperation(identifier: "6") {
            let start = ProcessInfo.processInfo.systemUptime
            print("Start Performing 6 - \(ProcessInfo.processInfo.systemUptime - allStart)")
            var p = 0
            for n in 0...Int(Double(scaling) * 0.3) {
                p += n
            }
            print("Done Performing 6 : \(Double(scaling) * 0.3) - \(ProcessInfo.processInfo.systemUptime - allStart)")
            operatingIntervals.append((start - allStart, ProcessInfo.processInfo.systemUptime - allStart))
        }
        print("enqueuing 7 - \(ProcessInfo.processInfo.systemUptime - allStart)")
        await atomicQueue.enqueueOperation(identifier: "7") {
            let start = ProcessInfo.processInfo.systemUptime
            print("Start Performing 7 - \(ProcessInfo.processInfo.systemUptime - allStart)")
            var p = 0
            for n in 0...Int(Double(scaling) * 0.05) {
                p += n
            }
            print("Done Performing 7 : \(Double(scaling) * 0.05) - \(ProcessInfo.processInfo.systemUptime - allStart)")
            operatingIntervals.append((start - allStart, ProcessInfo.processInfo.systemUptime - allStart))
        }
        try await Task.sleep(nanoseconds: 5.0.nanoSeconds)
        for interval in operatingIntervals {
            print("\(interval.0) - \(interval.1)")
        }
        for n in 1..<operatingIntervals.count {
            XCTAssertTrue(operatingIntervals[n-1].1 < operatingIntervals[n].0, "Intervals overlap - cannot guarantee atomicity")
        }
        var delaysBetweenTasks = [TimeInterval]()
        for n in 1..<operatingIntervals.count {
            delaysBetweenTasks.append(operatingIntervals[n].0 - operatingIntervals[n-1].1)
        }
        print(delaysBetweenTasks)
        for delay in delaysBetweenTasks {
            XCTAssertLessThan(delay, 0.6, "performance of waiting could be problematic")
        }
        XCTAssertEqual(operatingIntervals.count, 7, "all 7 operations should have finished, if older hardware, may need to adjust scaling")
    }
    
    actor OperatingIntervals {
        private var operatingIntervals = [(TimeInterval, TimeInterval)]()
        
        func append(_ interval: (TimeInterval, TimeInterval)) {
            operatingIntervals.append(interval)
        }
        
        func allIntervals() -> [(TimeInterval, TimeInterval)] {
            return operatingIntervals
        }
    }
    
    func testASyncAtomicOperationAsyncAwait() async throws {
        let atomicQueue = AsyncAtomicOperationQueue()
        let allStart = ProcessInfo.processInfo.systemUptime
        let intervals = OperatingIntervals()
        let scaling: Double = 3_000_000
        Task {
            print("enqueuing 1 - \(ProcessInfo.processInfo.systemUptime - allStart)")
            await atomicQueue.takeLock(identifier: "1")
            let start = ProcessInfo.processInfo.systemUptime
            print("Start Performing 1 - \(ProcessInfo.processInfo.systemUptime - allStart)")
            var p = 0
            for n in 0...Int(scaling) {
                p += n
            }
            print("Done Performing 1 : \(scaling) - \(ProcessInfo.processInfo.systemUptime - allStart)")
            await intervals.append((start - allStart, ProcessInfo.processInfo.systemUptime - allStart))
            await atomicQueue.releaseLock()
        }
        Task {
            print("enqueuing 2 - \(ProcessInfo.processInfo.systemUptime - allStart)")
            await atomicQueue.takeLock(identifier: "2")
            let start = ProcessInfo.processInfo.systemUptime
            print("Start Performing 2 - \(ProcessInfo.processInfo.systemUptime - allStart)")
            var p = 0
            for n in 0...Int(scaling * 0.25) {
                p += n
            }
            print("Done Performing 2 : \(scaling * 0.25) - \(ProcessInfo.processInfo.systemUptime - allStart)")
            await intervals.append((start - allStart, ProcessInfo.processInfo.systemUptime - allStart))
            await atomicQueue.releaseLock()
        }
        Task {
            print("enqueuing 3 - \(ProcessInfo.processInfo.systemUptime - allStart)")
            await atomicQueue.takeLock(identifier: "3")
            let start = ProcessInfo.processInfo.systemUptime
            print("Start Performing 3 - \(ProcessInfo.processInfo.systemUptime - allStart)")
            var p = 0
            for n in 0...Int(scaling * 0.4) {
                p += n
            }
            print("Done Performing 3 : \(scaling * 0.4) - \(ProcessInfo.processInfo.systemUptime - allStart)")
            await intervals.append((start - allStart, ProcessInfo.processInfo.systemUptime - allStart))
            await atomicQueue.releaseLock()
        }
        Task {
            print("enqueuing 4 - \(ProcessInfo.processInfo.systemUptime - allStart)")
            await atomicQueue.takeLock(identifier: "4")
            let start = ProcessInfo.processInfo.systemUptime
            print("Start Performing 4 - \(ProcessInfo.processInfo.systemUptime - allStart)")
            var p = 0
            for n in 0...Int(scaling * 0.1) {
                p += n
            }
            print("Done Performing 4 : \(scaling * 0.1) - \(ProcessInfo.processInfo.systemUptime - allStart)")
            await intervals.append((start - allStart, ProcessInfo.processInfo.systemUptime - allStart))
            await atomicQueue.releaseLock()
        }
        Task {
            print("enqueuing 5 - \(ProcessInfo.processInfo.systemUptime - allStart)")
            await atomicQueue.takeLock(identifier: "5")
            let start = ProcessInfo.processInfo.systemUptime
            print("Start Performing 5 - \(ProcessInfo.processInfo.systemUptime - allStart)")
            var p = 0
            for n in 0...Int(scaling * 0.05) {
                p += n
            }
            print("Done Performing 5 : \(scaling * 0.05) - \(ProcessInfo.processInfo.systemUptime - allStart)")
            await intervals.append((start - allStart, ProcessInfo.processInfo.systemUptime - allStart))
            await atomicQueue.releaseLock()
        }
        Task {
            print("enqueuing 6 - \(ProcessInfo.processInfo.systemUptime - allStart)")
            await atomicQueue.takeLock(identifier: "6")
            let start = ProcessInfo.processInfo.systemUptime
            print("Start Performing 6 - \(ProcessInfo.processInfo.systemUptime - allStart)")
            var p = 0
            for n in 0...Int(scaling * 0.3) {
                p += n
            }
            print("Done Performing 6 : \(scaling * 0.3) - \(ProcessInfo.processInfo.systemUptime - allStart)")
            await intervals.append((start - allStart, ProcessInfo.processInfo.systemUptime - allStart))
            await atomicQueue.releaseLock()
        }
        Task {
            print("enqueuing 7 - \(ProcessInfo.processInfo.systemUptime - allStart)")
            await atomicQueue.takeLock(identifier: "7")
            let start = ProcessInfo.processInfo.systemUptime
            print("Start Performing 7 - \(ProcessInfo.processInfo.systemUptime - allStart)")
            var p = 0
            for n in 0...Int(scaling * 0.05) {
                p += n
            }
            print("Done Performing 7 : \(scaling * 0.05) - \(ProcessInfo.processInfo.systemUptime - allStart)")
            await intervals.append((start - allStart, ProcessInfo.processInfo.systemUptime - allStart))
            await atomicQueue.releaseLock()
        }
        try await Task.sleep(nanoseconds: 5.0.nanoSeconds)
        let operatingIntervals = await intervals.allIntervals()
        for interval in operatingIntervals {
            print("\(interval.0) - \(interval.1)")
        }
        for n in 1..<operatingIntervals.count {
            XCTAssertTrue(operatingIntervals[n-1].1 < operatingIntervals[n].0, "Intervals overlap - cannot guarantee atomicity")
        }
        var delaysBetweenTasks = [TimeInterval]()
        for n in 1..<operatingIntervals.count {
            delaysBetweenTasks.append(operatingIntervals[n].0 - operatingIntervals[n-1].1)
        }
        print(delaysBetweenTasks)
        for delay in delaysBetweenTasks {
            XCTAssertLessThan(delay, 0.6, "performance of waiting could be problematic")
        }
        XCTAssertEqual(operatingIntervals.count, 7, "all 7 operations should have finished, if older hardware, may need to adjust scaling")
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
