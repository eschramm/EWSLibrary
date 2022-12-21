//
//  AsyncTools.swift
//  
//
//  Created by Eric Schramm on 12/21/22.
//

import Foundation

public actor AsyncTimer {
    
    let interval: TimeInterval
    let fireClosure: () -> ()
    var fireTask: Task<Void, Never>?
    
    var isRunning = false
    
    public init(interval: TimeInterval, fireClosure: @escaping () -> ()) {
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
            try? await Task.sleep(nanoseconds: UInt64(interval * 1000) * 1_000_000)
            fire()
        }
    }
    
    func fire() {
        guard isRunning else { return }
        fireTask = Task { fireClosure() }
        Task {
            await fireTask?.value
            try? await Task.sleep(nanoseconds: UInt64(interval * 1000) * 1_000_000)
            fire()
        }
    }
    
    func stop() {
        fireTask?.cancel()
        isRunning = false
    }
}
