//
//  TimeStamper.swift
//  EWSLibrary
//
//  Created by Eric Schramm on 3/27/20.
//  Copyright © 2020 eware. All rights reserved.
//

import Foundation


public class TimeProfiler {
    
    public enum Granularity {
        case automatic
        case manual(NSCalendar.Unit)
    }
    
    struct TimeStamp {
        let timeStamp: TimeInterval
        let tag: String
    }
    
    var timeStamps = [TimeStamp]()
    
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
    
    public func stamp(tag: String) {
        timeStamps.append(TimeStamp(timeStamp: ProcessInfo.processInfo.systemUptime, tag: tag))
    }
    
    public func report() -> String {
        var lastTimeStamp: TimeStamp?
        var lines = [String]()
        for timeStamp in timeStamps {
            lines.append(reportLine(timeStamp: timeStamp, lastTimeStamp: lastTimeStamp))
            lastTimeStamp = timeStamp
        }
        return lines.joined(separator: "\n")
    }
    
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

public class ProgressTimeProfiler {

    struct ProgressTimeStamp {
        let timeStamp: TimeInterval
        let workComplete: Int
        let fractionComplete: Double
    }
    
    var timeStamps = [ProgressTimeStamp]()
    public let totalWork: Int
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
    var lastResultWeight = 0.6
    
    public init(totalWorkUnits: Int) {
        self.totalWork = totalWorkUnits
    }
    
    public func stamp(withWorkUnitsComplete workUnitsComplete: Int) {
        timeStamps.append(ProgressTimeStamp(timeStamp: ProcessInfo.processInfo.systemUptime, workComplete: workUnitsComplete, fractionComplete: Double(workUnitsComplete) / Double(totalWork)))
    }
    
    public func progress(showRawUnits: Bool = false) -> String {
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
            if firstFractionComplete == nil {
                firstFractionComplete = timeStamp.fractionComplete
            }
            lastInstant = timeStamp.timeStamp
            lastCount = timeStamp.workComplete
        }
        
        // assumes called at symmetric intervals, e.g. every 10,000, etc.
        var secondsRemaining: Double?
        var secondsSoFar: Double?
        if timeSum > 0, timeStamps.count > 1, let firstFractionComplete = firstFractionComplete, let lastTimeStamp = timeStamps.last {
            secondsSoFar = Double(timeSum) / (lastTimeStamp.fractionComplete - firstFractionComplete) * lastTimeStamp.fractionComplete
            let totalRate = lastTimeStamp.fractionComplete / secondsSoFar!
            let secondToLastTimeStamp = timeStamps[timeStamps.count - 2]
            let lastFractionCompleteDiff = lastTimeStamp.fractionComplete - secondToLastTimeStamp.fractionComplete
            let lastInterval = lastTimeStamp.timeStamp - secondToLastTimeStamp.timeStamp
            let lastRate = lastFractionCompleteDiff / Double(lastInterval)
            let weightedRate = (totalRate * (1 - lastResultWeight)) + (lastRate * lastResultWeight)
            secondsRemaining = (1 - lastTimeStamp.fractionComplete) / weightedRate
        }
        var output = ""
        if let secondsRemaining = secondsRemaining, let secondsSoFar = secondsSoFar {
            output = "Elapsed: \(timeFormatter.string(from: secondsSoFar)!) - Est time remaining: \(timeFormatter.string(from: secondsRemaining)!) - "
        }
        if let lastTimeStamp = timeStamps.last {
            let percentComplete = lastTimeStamp.fractionComplete * 100
            output += "\(numberFormatter.string(for: percentComplete)!) %"
            if showRawUnits {
                output += " (\(numberFormatter.string(for: lastTimeStamp.workComplete)!) of \(numberFormatter.string(for: totalWork)!))"
            }
        }

        return output
    }
}



func timeStampDiff(start: TimeInterval, end: TimeInterval) -> String {
    let diffInSeconds = end - start
    return "\(diffInSeconds) seconds"
}
