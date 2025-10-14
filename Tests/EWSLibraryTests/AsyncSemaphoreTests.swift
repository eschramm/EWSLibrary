import XCTest
@testable import EWSLibrary

final class AsyncSemaphoreTests: XCTestCase {
    
    actor Counter {
        private var current = 0
        private(set) var maxConcurrent = 0
        
        func increment() {
            current += 1
            if current > maxConcurrent {
                maxConcurrent = current
            }
        }
        
        func decrement() {
            current -= 1
        }
    }
    
    func testConcurrentLimitRespected() async throws {
        let sem = AsyncSemaphore(limit: 3)
        let counter = Counter()
        
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<20 {
                group.addTask {
                    await sem.acquire()
                    await counter.increment()
                    try? await Task.sleep(nanoseconds: 50_000_000) // 50ms
                    // update maxConcurrent happens inside increment already
                    await counter.decrement()
                    await sem.release()
                }
            }
        }
        
        let max = await counter.maxConcurrent
        XCTAssertEqual(max, 3)
    }
    
    func testWaiterResumesOnRelease() async throws {
        let sem = AsyncSemaphore(limit: 1)
        await sem.acquire() // acquire first permit, semaphore is now 0 available
        
        let flag = ActorFlag()
        
        let task = Task {
            await sem.acquire()
            await flag.setTrue()
            await sem.release()
        }
        
        try? await Task.sleep(nanoseconds: 50_000_000) // wait 50ms to let task try to acquire
        
        let flagValueBeforeRelease = await flag.value
        XCTAssertFalse(flagValueBeforeRelease)
        
        await sem.release()
        
        let exp = expectation(description: "Wait for flag to become true")
        
        // Wait up to 1s for flag to be true
        Task {
            for _ in 0..<20 {
                if await flag.value {
                    exp.fulfill()
                    return
                }
                try? await Task.sleep(nanoseconds: 50_000_000)
            }
        }
        
        await fulfillment(of: [exp], timeout: 1.0)
        let flagValueAfterRelease = await flag.value
        XCTAssertTrue(flagValueAfterRelease)
        
        await task.value
    }
    
    actor ActorFlag {
        private var internalValue = false
        
        var value: Bool {
            internalValue
        }
        
        func setTrue() {
            internalValue = true
        }
    }
    
    actor Tally {
        private var currentCount = 0
        private(set) var maxConcurrent = 0
        
        func enter() {
            currentCount += 1
            if currentCount > maxConcurrent {
                maxConcurrent = currentCount
            }
        }
        
        func exit() {
            currentCount -= 1
        }
        
        var current: Int {
            currentCount
        }
    }
    
    func testAcquireReleaseBalanceUnderContention() async throws {
        let sem = AsyncSemaphore(limit: 2)
        let tally = Tally()
        
        await withTaskGroup(of: Void.self) { group in
            for _ in 0..<50 {
                group.addTask {
                    await sem.acquire()
                    await tally.enter()
                    let delay = UInt64(Int.random(in: 5_000_000...15_000_000)) // 5-15ms
                    try? await Task.sleep(nanoseconds: delay)
                    await tally.exit()
                    await sem.release()
                }
            }
        }
        
        let current = await tally.current
        let maxConcurrent = await tally.maxConcurrent
        
        XCTAssertEqual(current, 0)
        XCTAssertLessThanOrEqual(maxConcurrent, 2)
    }
}
