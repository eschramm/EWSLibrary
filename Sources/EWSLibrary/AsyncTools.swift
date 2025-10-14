//
//  AsyncTools.swift
//  
//
//  Created by Eric Schramm on 12/21/22.
//

import Foundation

public extension TimeInterval {
    var nanoSeconds: UInt64 {
        return UInt64(self * 1000) * 1_000_000
    }
}

public actor AsyncTimer {
    
    let interval: TimeInterval
    let fireClosure: @Sendable (AsyncTimer) -> ()
    var fireTask: Task<Void, Never>?
    
    var isRunning = false
    
    public init(interval: TimeInterval, fireClosure: @escaping @Sendable (AsyncTimer) -> ()) {
        self.interval = interval
        self.fireClosure = fireClosure
    }
    
    public func start(fireNow: Bool) async {
        guard !isRunning else {
            return
        }
        isRunning = true
        if fireNow {
            fire(once: true)
        }
        Task {
            try? await Task.sleep(nanoseconds: interval.nanoSeconds)
            fire(once: false)
        }
    }
    
    public func fire(once: Bool) {
        guard isRunning else { return }
        fireTask = Task { fireClosure(self) }
        guard !once else { return }
        Task {
            await fireTask?.value
            try? await Task.sleep(nanoseconds: interval.nanoSeconds)
            fire(once: false)
        }
    }
    
    public func stop() {
        fireTask?.cancel()
        isRunning = false
    }
}

/*
 The AsyncAtomicOperationQueue is intended to create atomic access to a critical section
 in async-await that may yield (await). Order of operations is not guaranteed when
 there is contention. Note: enqueueOperation can be blocked/delayed by a long-running
 synchronous operation.
 
 synchronous closure usage:
 
 let atomicActor = AsyncAtomicOperationQueue()
 atomicActor.enqueueOperation {
     FileManager.default.removeItem(at: url)
 }
 
 async-await usage:
 
 let atomicActor = AsyncAtomicOperationQueue()
 await atomicActor.takeLock()
 FileManager.default.remove(at: url)
 await atomicActor.releaseLock()
 */

public actor AsyncAtomicOperationQueue {
    
    let randomSleepRange: Range<TimeInterval>
    var sharedOperationInProgress = false
    
    public init(randomSleepRange: Range<TimeInterval> = 0.1..<0.5) {
        self.randomSleepRange = randomSleepRange
    }
    
    public func enqueueOperation(identifier: String = "", operation: @Sendable @escaping () -> ()) {
        //print("START: \(ProcessInfo.processInfo.systemUptime)")
        Task {
            await takeLock(identifier: identifier)
            await Task.yield()
            operation()
            releaseLock()
        }
        //print("END  : \(ProcessInfo.processInfo.systemUptime)")
    }
    
    public func takeLock(identifier: String = "") async {
        //print("taking lock")
        while sharedOperationInProgress {
            //print("awaiting - \(identifier)")
            try? await Task.sleep(nanoseconds: UInt64.random(in: randomSleepRange.lowerBound.nanoSeconds..<randomSleepRange.upperBound.nanoSeconds))
        }
        sharedOperationInProgress = true
    }
    
    public func releaseLock() {
        sharedOperationInProgress = false
    }
}

/// **AsyncSemaphore**
/// Allows for controlled concurrency - like a concurrent queue with a cap of concurrent operations
/// Example:
/*
 let pool = AsyncSemaphore(limit: 3)
 return try await withThrowingTaskGroup(of: ScanChunk.self) { group in
     // Seed the root directory/file
     group.addTask {
         await pool.acquire()
         do {
             let chunk = try await doWork()
             await pool.release()
             return chunk
         } catch {
             await pool.release()
             throw error
         }
     }

     var totalWorkStuffs = 0

     for try await chunk in group {
         // Aggregate immediate stats
         totalWorkStuffs += chunk.workCount
         
         // Even allows adding subchunks while queue is working (like recursion)
         for subdir in chunk.subdirs {
             group.addTask {
                 await pool.acquire()
                 do {
                     let subChunk = try await doWork()
                     await pool.release()
                     return subChunk
                 } catch {
                     await pool.release()
                     throw error
                 }
             }
         }
     }

     return totalWorkStuffs
 */

public actor AsyncSemaphore {
    private let limit: Int
    private var current = 0
    private var waiters: [CheckedContinuation<Void, Never>] = []
    
    /// Allows for controlled concurrency - like a concurrent queue with a cap of concurrent operations
    /// - Parameter limit: number of concurrent operations allowed
    public init(limit: Int) { self.limit = limit }
    
    public func acquire() async {
        if current < limit {
            current += 1
            return
        }
        await withCheckedContinuation { cont in
            waiters.append(cont)
        }
    }
    
    public func release() {
        if !waiters.isEmpty {
            let cont = waiters.removeFirst()
            cont.resume()
        } else {
            current = max(0, current - 1)
        }
    }
}
