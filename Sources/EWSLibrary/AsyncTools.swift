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
    let fireClosure: (AsyncTimer) -> ()
    var fireTask: Task<Void, Never>?
    
    var isRunning = false
    
    public init(interval: TimeInterval, fireClosure: @escaping (AsyncTimer) -> ()) {
        self.interval = interval
        self.fireClosure = fireClosure
    }
    
    public func start(fireNow: Bool) async {
        guard !isRunning else {
            return
        }
        isRunning = true
        if fireNow {
            fire()
        }
        Task {
            try? await Task.sleep(nanoseconds: interval.nanoSeconds)
            fire()
        }
    }
    
    func fire() {
        guard isRunning else { return }
        fireTask = Task { fireClosure(self) }
        Task {
            await fireTask?.value
            try? await Task.sleep(nanoseconds: interval.nanoSeconds)
            fire()
        }
    }
    
    func stop() {
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
    
    public func enqueueOperation(identifier: String = "", operation: @escaping () -> ()) {
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
