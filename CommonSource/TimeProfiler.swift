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
        let timeStamp: UInt64
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
        timeStamps.append(TimeStamp(timeStamp: mach_absolute_time(), tag: tag))
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
        let nanoSecondDifference = timeStamp.timeStamp - lastTimeStamp.timeStamp
        let unit: NSCalendar.Unit
        switch granularity {
        case .automatic:
            switch nanoSecondDifference {
            case 0...1000:
                unit = .nanosecond
            case 1000...90_000_000_000:                   // 90 sec
                unit = .second
            case 90_000_000_000...(90_000_000_000 * 60):  // 90 min
                unit = .minute
            case (90_000_000_000 * 60)...(1_000_000_000 * 60 * 60 * 36):  // 36 hours
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
            double = Double(nanoSecondDifference)
            unitString = "ns "
        case .second:
            double = Double(nanoSecondDifference) / Double(1_000_000_000)
            unitString = "sec"
        case .minute:
            double = Double(nanoSecondDifference) / Double(1_000_000_000 * 60)
            unitString = "min"
        case .hour:
            double = Double(nanoSecondDifference) / Double(1_000_000_000 * 60 * 60)
            unitString = "hr "
        default:
            double = Double(nanoSecondDifference) / Double(1_000_000_000 * 60 * 60 * 24)
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

class ProgressTimeProfiler {

    struct ProgressTimeStamp {
        let timeStamp: UInt64
        let workComplete: Int
        let fractionComplete: Double
    }
    
    var timeStamps = [ProgressTimeStamp]()
    let totalWork: Int
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
    
    init(totalWorkUnits: Int) {
        self.totalWork = totalWorkUnits
    }
    
    func stamp(with workUnitsComplete: Int) {
        timeStamps.append(ProgressTimeStamp(timeStamp: mach_absolute_time(), workComplete: workUnitsComplete, fractionComplete: Double(workUnitsComplete) / Double(totalWork)))
    }
    
    func progress(showRawUnits: Bool = false) -> String {
        var timeSum: UInt64 = 0
        var countSum = 0
        var lastInstant: UInt64?
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
        
        //assumes called at symmetric intervals, e.g. every 10,000, etc.
        var nanoSecondsRemaining: Double?
        var nanoSecondsSoFar: Double?
        if timeSum > 0, timeStamps.count > 1, let firstFractionComplete = firstFractionComplete, let lastTimeStamp = timeStamps.last {
            nanoSecondsSoFar = Double(timeSum) / (lastTimeStamp.fractionComplete - firstFractionComplete) * lastTimeStamp.fractionComplete
            let totalRate = lastTimeStamp.fractionComplete / nanoSecondsSoFar!
            let secondToLastTimeStamp = timeStamps[timeStamps.count - 2]
            let lastFractionCompleteDiff = lastTimeStamp.fractionComplete - secondToLastTimeStamp.fractionComplete
            let lastInterval = lastTimeStamp.timeStamp - secondToLastTimeStamp.timeStamp
            let lastRate = lastFractionCompleteDiff / Double(lastInterval)
            let weightedRate = (totalRate * (1 - lastResultWeight)) + (lastRate * lastResultWeight)
            nanoSecondsRemaining = (1 - lastTimeStamp.fractionComplete) / weightedRate
        }
        var output = ""
        if let nanoSecondsRemaining = nanoSecondsRemaining, let nanoSecondsSoFar = nanoSecondsSoFar {
            let secSoFar: TimeInterval = Double(Double(Int(Double(nanoSecondsSoFar) / 1_000_000_000 * 10000)) / 10000)  //round to four decimal places
            let diffInSeconds: TimeInterval = Double(Double(Int(Double(nanoSecondsRemaining) / 1_000_000_000 * 10000)) / 10000)  //round to four decimal places
            output = "Elapsed: \(timeFormatter.string(from: secSoFar)!) - Est time remaining: \(timeFormatter.string(from: diffInSeconds)!) - "
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



func timeStampDiff(start: UInt64, end: UInt64) -> String {
    let diffInNanoseconds = end - start
    let diffInSeconds = Double(Double(Int(Double(diffInNanoseconds) / 1_000_000_000 * 10000)) / 10000)  //round to four decimal places
    return "\(diffInSeconds) seconds"
}
