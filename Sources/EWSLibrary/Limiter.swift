//
//  Limiter.swift
//  
//
//  Created by Eric Schramm on 7/11/22.
//

import Foundation

// https://codereview.stackexchange.com/questions/269642/debounce-and-throttle-tasks-using-swift-concurrency

@available(macOS 12, *)
public actor Limiter {
    private let policy: Policy
    private let duration: TimeInterval
    private var task: Task<Void, Error>?

    public init(policy: Policy, duration: TimeInterval) {
        self.policy = policy
        self.duration = duration
    }

    public func submit(operation: @escaping () async -> Void) {
        switch policy {
        case .throttle: throttle(operation: operation)
        case .debounce: debounce(operation: operation)
        }
    }
}

// MARK: - Limiter.Policy

@available(macOS 12, *)
public extension Limiter {
    enum Policy {
        ///will run first task after duration and ignore subsequent until complete
        case throttle
        
        ///will run last task after duration, resetting every duration
        case debounce
    }
}

// MARK: - Private utility methods

@available(macOS 12, *)
private extension Limiter {
    func throttle(operation: @escaping () async -> Void) {
        guard task == nil else { return }

        task = Task {
            try? await sleep()
            task = nil
        }

        Task {
            await operation()
        }
    }

    func debounce(operation: @escaping () async -> Void) {
        task?.cancel()

        task = Task {
            try await sleep()
            await operation()
            task = nil
        }
    }

    func sleep() async throws {
        try await Task.sleep(nanoseconds: UInt64(duration * .nanosecondsPerSecond))
    }
}

// MARK: - TimeInterval

extension TimeInterval {
    static let nanosecondsPerSecond = TimeInterval(NSEC_PER_SEC)
}
