//
//  TimeStamper.swift
//  EWSLibrary
//
//  Created by Eric Schramm on 3/27/20.
//  Copyright © 2020 eware. All rights reserved.
//

import Foundation

@MainActor
public final class TimeProfiler: Sendable {
    
    public enum Granularity {
        case automatic
        case manual(NSCalendar.Unit)
    }
    
    struct TimeStamp: Sendable {
        let timeStamp: TimeInterval
        let tag: String
    }
    
    var timeStamps = [Int: [TimeStamp]]()
    
    let numberFormatter = NumberFormatter()
    
    public var granularity = Granularity.automatic
    
    public init(maximumFractionDigits: Int? = nil) {
        numberFormatter.numberStyle = .decimal
        if let maximumFractionDigits = maximumFractionDigits {
            numberFormatter.maximumFractionDigits = maximumFractionDigits
        } else {
            numberFormatter.maximumSignificantDigits = 12
        }
    }
    
    nonisolated public func stamp(tag: String, trial: Int = 0) {
        let timeStamp = ProcessInfo.processInfo.systemUptime
        Task { @MainActor in
            var trialTimeStamps = timeStamps[trial] ?? [TimeStamp]()
            trialTimeStamps.append(TimeStamp(timeStamp: timeStamp, tag: tag))
            timeStamps[trial] = trialTimeStamps
        }
    }
    
    /// Return a simple multi-line report as a String of stats
    /// - Parameter trial: if empty, will perform combined stats for all trials, otherwise only for the trial provided
    /// - Returns: if no trials used, a simple timeStamp-to-timeStamp time intervals, otherwise mean/stDev for each step for all trials
    public func report(trial: Int? = nil) -> String {
        var lastTimeStamp: TimeStamp?
        var lines = [String]()
        if timeStamps.count == 1 {
            if let trialStamps = timeStamps.first?.value {
                for timeStamp in trialStamps {
                    lines.append(reportLine(timeStamp: timeStamp, lastTimeStamp: lastTimeStamp))
                    lastTimeStamp = timeStamp
                }
            }
        } else {
            if let trial = trial {
                if let trialStamps = timeStamps[trial] {
                    for timeStamp in trialStamps {
                        lines.append(reportLine(timeStamp: timeStamp, lastTimeStamp: lastTimeStamp))
                        lastTimeStamp = timeStamp
                    }
                }
            } else {
                // summarize
                var dataDict = [String : [TimeInterval]]()
                for (_, timeStamps) in timeStamps {
                    for idx in 1..<timeStamps.count {
                        let interval = timeStamps[idx].timeStamp - timeStamps[idx - 1].timeStamp
                        let key = "[\(idx)]: \(timeStamps[idx - 1].tag) - \(timeStamps[idx].tag)"
                        var intervals = dataDict[key] ?? [TimeInterval]()
                        intervals.append(interval)
                        dataDict[key] = intervals
                    }
                    // full run
                    let key = "[FULL RUN]"
                    var intervals = dataDict[key] ?? [TimeInterval]()
                    intervals.append(timeStamps[timeStamps.count - 1].timeStamp - timeStamps[0].timeStamp)
                    dataDict[key] = intervals
                }
                let sortedKeys = dataDict.keys.sorted()
                lines = sortedKeys.map({ (key) -> String in
                    let intervals = dataDict[key]!
                    let stats = intervals.stats()
                    return """
                           \(key)
                           n     = \(intervals.count)
                           mean  = \(stats.string(stat: .mean, numberFormatter: numberFormatter))
                           range = \(stats.string(stat: .min, numberFormatter: numberFormatter)) - \(stats.string(stat: .max, numberFormatter: numberFormatter))
                           stDev = \(stats.string(stat: .stDev, numberFormatter: numberFormatter)) (\(stats.string(stat: .relDev, numberFormatter: numberFormatter)))
                           ---
                           \(intervals.map({ numberFormatter.string(for: $0)! }).joined(separator: "\n"))
                           """
                })
            }
        }
        return lines.joined(separator: "\n")
    }
    /*
    public func reportOnlyRawSegmentNumbers() -> String {
        var lines = [String]()
        for idx in 1..<timeStamps.count {
            let distance = timeStamps[idx].timeStamp - timeStamps[idx - 1].timeStamp
            lines.append("\(distance)")
        }
        return lines.joined(separator: "\n")
    }*/
    
    private func reportLine(timeStamp: TimeStamp, lastTimeStamp: TimeStamp?) -> String {
        let lineLength = 80
        let timeLength = 12
        guard let lastTimeStamp = lastTimeStamp else {
            return (String(repeating: "-", count: timeLength + 7 - 1) + " " + timeStamp.tag).trunc(length: lineLength - (timeLength + 7))
        }
        let secondDifference = timeStamp.timeStamp - lastTimeStamp.timeStamp
        let unit: NSCalendar.Unit
        switch granularity {
        case .automatic:
            switch secondDifference {
            case 0...0.000001000:
                unit = .nanosecond
            case 0.000001000...90:            // 90 sec
                unit = .second
            case 90...(90 * 60):              // 90 min
                unit = .minute
            case (90 * 60)...(60 * 60 * 36):  // 36 hours
                unit = .hour
            default:
                unit = .day
            }
        case .manual(let manualUnit):
            unit = manualUnit
        }
        let double: Double
        let unitString: String  // length of 3 char
        switch unit {
        case .nanosecond:
            double = secondDifference / 1_000_000_000
            unitString = "ns "
        case .second:
            double = secondDifference
            unitString = "sec"
        case .minute:
            double = secondDifference / 60
            unitString = "min"
        case .hour:
            double = secondDifference / (60 * 60)
            unitString = "hr "
        default:
            double = secondDifference / (60 * 60 * 24)
            unitString = "day"
        }
        let numberString = (numberFormatter.string(for: double) ?? "").trunc(length: timeLength, trailing: "")
        
        return "\(String(repeating: " ", count: timeLength - numberString.count))\(numberString) \(unitString) : \(timeStamp.tag)"
    }
    
    
}

extension String {
    func trunc(length: Int, trailing: String = "…") -> String {
      return (self.count > length) ? self.prefix(length) + trailing : self
    }
}

@MainActor
public final class ProgressTimeProfiler: Sendable {

    struct ProgressTimeStamp: Sendable {
        let timeStamp: TimeInterval
        let workComplete: Int
        let fractionComplete: Double
    }
    
    var timeStamps = [ProgressTimeStamp]()
    public var totalWork: Int
    let timeFormatter: DateComponentsFormatter = {
        let dcf = DateComponentsFormatter()
        dcf.allowedUnits = [.day, .hour, .minute, .second]
        dcf.unitsStyle = .abbreviated
        //dcf.maximumUnitCount = 1
        return dcf
    }()
    let numberFormatter: NumberFormatter = {
        let nf = NumberFormatter()
        nf.numberStyle = .decimal
        nf.maximumFractionDigits = 2
        return nf
    }()
    let lastResultWeight: Double?
    
    /**
    Creates a ProgressTimeProfiler which will track progress and predict time to completion

    - Parameter totalWorkUnits: The count of total items to process
    - Parameter lastResultWeight: Default 0.6 - how much to weight the last reported work completed against the running average. If nil, will weight all work evenly
    */
    public init(totalWorkUnits: Int, lastResultWeight: Double? = 0.6) {
        self.totalWork = totalWorkUnits
        self.lastResultWeight = lastResultWeight
    }
    
    nonisolated public func stamp(withWorkUnitsComplete workUnitsComplete: Int) {
        let timeStamp = ProcessInfo.processInfo.systemUptime
        Task { @MainActor in
            timeStamps.append(ProgressTimeStamp(timeStamp: timeStamp, workComplete: workUnitsComplete, fractionComplete: Double(workUnitsComplete) / Double(totalWork)))
        }
    }
    
    public func progress(showRawUnits: Bool, showEstTotalTime: Bool) -> String {
        var timeSum: TimeInterval = 0
        var countSum = 0
        var lastInstant: TimeInterval?
        var lastCount: Int?
        var firstFractionComplete: Double?
        for timeStamp in timeStamps {
            if let lastInstant = lastInstant, let lastCount = lastCount {
                timeSum += (timeStamp.timeStamp - lastInstant)
                countSum += (timeStamp.workComplete - lastCount)
            }
            if firstFractionComplete == nil, !timeStamp.fractionComplete.isNaN {
                firstFractionComplete = timeStamp.fractionComplete
            }
            lastInstant = timeStamp.timeStamp
            lastCount = timeStamp.workComplete
        }
        
        // assumes called at symmetric intervals, e.g. every 10,000, etc.
        var secondsRemaining: Double?
        var secondsSoFar: Double?
        if timeSum > 0, timeStamps.count > 1, let firstFractionComplete, let lastTimeStamp = timeStamps.last, lastTimeStamp.fractionComplete - firstFractionComplete > 0 {
            secondsSoFar = Double(timeSum) / (lastTimeStamp.fractionComplete - firstFractionComplete) * lastTimeStamp.fractionComplete
            let totalRate = lastTimeStamp.fractionComplete / secondsSoFar!
            let secondToLastTimeStamp = timeStamps[timeStamps.count - 2]
            let lastFractionCompleteDiff = lastTimeStamp.fractionComplete - secondToLastTimeStamp.fractionComplete
            let lastInterval = lastTimeStamp.timeStamp - secondToLastTimeStamp.timeStamp
            let lastRate = lastFractionCompleteDiff / Double(lastInterval)
            let weightedRate: Double
            if let lastResultWeight = lastResultWeight {
                weightedRate = (totalRate * (1 - lastResultWeight)) + (lastRate * lastResultWeight)
            } else {
                weightedRate = totalRate
            }
            if weightedRate > 0 {
                secondsRemaining = (1 - lastTimeStamp.fractionComplete) / weightedRate
            }
        }
        var output = ""
        if let lastTimeStamp = timeStamps.last, lastTimeStamp.fractionComplete >= 1, let secondsSoFar {
            output = "COMPLETE - Total time: \(timeFormatter.string(from: secondsSoFar)!) [\(numberFormatter.string(for: totalWork)!)]"
        } else {
            if let secondsRemaining , let secondsSoFar {
                output = "Elapsed: \(timeFormatter.string(from: secondsSoFar)!) - Est left: \(timeFormatter.string(from: secondsRemaining)!) - "
                if showEstTotalTime {
                    let estimatedTotalTime = secondsSoFar + secondsRemaining
                    output += " [Est total: \(timeFormatter.string(from: estimatedTotalTime)!)] "
                }
            }
            if let lastTimeStamp = timeStamps.last {
                let percentComplete = lastTimeStamp.fractionComplete * 100
                output += "\(numberFormatter.string(for: percentComplete)!) %"
                if showRawUnits {
                    output += " (\(numberFormatter.string(for: lastTimeStamp.workComplete)!) of \(numberFormatter.string(for: totalWork)!))"
                }
            }
        }

        return output
    }
}

func timeStampDiff(start: TimeInterval, end: TimeInterval) -> String {
    let diffInSeconds = end - start
    return "\(diffInSeconds) seconds"
}

public class Debouncer: NSObject {
    let callback: (() -> ())
    let delay: Double
    let useDelayAsThrottle: Bool
    weak var timer: Timer?
    
    /**
    Creates a Debouncer based on the callback

    - Parameter delay: The delay in seconds (TimeInterval
    - Parameter callback: The code to be executed when debounced
    - Parameter useDelayAsThrottle: when true, will always update, throttling at delay, otherwise will only update after a delay interval with no calls
    */
    public init(delay: Double, useDelayAsThrottle: Bool, callback: @escaping (() -> ())) {
        self.delay = delay
        self.callback = callback
        self.useDelayAsThrottle = useDelayAsThrottle
    }
    
    public func call() {
        if useDelayAsThrottle {
            guard timer == nil else { return }
            timer = Timer.scheduledTimer(timeInterval: delay, target: self, selector: #selector(Debouncer.fireNow), userInfo: nil, repeats: false)
        } else {
            timer?.invalidate()
            let nextTimer = Timer.scheduledTimer(timeInterval: delay, target: self, selector: #selector(Debouncer.fireNow), userInfo: nil, repeats: false)
            timer = nextTimer
        }
    }
    
    @objc func fireNow() {
        self.callback()
        if useDelayAsThrottle {
            timer = nil
        }
    }
}

public struct AppInfo {
    public static func currentMemory() -> Int {
        let TASK_VM_INFO_COUNT = MemoryLayout<task_vm_info_data_t>.size / MemoryLayout<natural_t>.size

        var vmInfo = task_vm_info_data_t()
        var vmInfoSize = mach_msg_type_number_t(TASK_VM_INFO_COUNT)

        let kern: kern_return_t = withUnsafeMutablePointer(to: &vmInfo) {
                $0.withMemoryRebound(to: integer_t.self, capacity: 1) {
                    task_info(machTaskSelf,
                              task_flavor_t(TASK_VM_INFO),
                              $0,
                              &vmInfoSize)
                    }
                }

        if kern == KERN_SUCCESS {
            let usedSize = Int(vmInfo.internal + vmInfo.compressed)
            //print("Memory in use (in bytes): %u", usedSize)
            return usedSize
        } else {
            let errorString = String(cString: mach_error_string(kern), encoding: .ascii) ?? "unknown error"
            print("Error with task_info(): %s", errorString)
            return 0
        }
    }
}
