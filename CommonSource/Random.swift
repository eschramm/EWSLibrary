//
//  Random.swift
//  EWSLibrary_iOS
//
//  Created by Eric Schramm on 4/5/20.
//  Copyright © 2020 eware. All rights reserved.
//

import Foundation

public func normalizedRandom(mean: Double, stDevRightTail: Double, stDevLeftTail: Double) -> Double {
    /*
    if distribution = 1, stDev = 1
    if distribution = 0.5, bimodal distribution at -1 and 1
    */
    let distribution: Double = 1
    var x1: Double = 0
    var x2: Double = 0
    var w:  Double = 0
    
    repeat {
        x1 = Double.random(in: 0...1)
        x2 = Double.random(in: 0...1)
        w = pow(x1, 2) + pow(x2, 2)
    } while (w >= distribution)
    
    w = pow((-2 * log10(w)) / w, 0.5)
    
    if Bool.random() {
        return x1 * w * stDevRightTail + mean
    } else {
        return x2 * w * -stDevLeftTail + mean
    }
}

public func randomBool(withTrueProbability trueProbability: Double) -> Bool {
    let precision = 1000
    let random = Int.random(in: 0..<precision)
    return Double(random) < Double(precision) * trueProbability
}

public struct EWSStats<T:FloatingPoint> {
    let sum: T
    let min: T?
    let max: T?
    let mean: T?
    let median: T?
    let standardDeviation: T?
    let relativeDeviation: T?
    
    enum Stat {
        case sum
        case min
        case max
        case mean
        case median
        case stDev
        case relDev
    }
    
    func string(stat: Stat, numberFormatter: NumberFormatter, naString: String = "--") -> String {
        switch stat {
        case .sum:
            return numberFormatter.string(for: sum)!
        case .min:
            return numberFormatter.string(for: min) ?? naString
        case .max:
            return numberFormatter.string(for: max) ?? naString
        case .mean:
            return numberFormatter.string(for: mean) ?? naString
        case .median:
            return numberFormatter.string(for: median) ?? naString
        case .stDev:
            return numberFormatter.string(for: standardDeviation) ?? naString
        case .relDev:
            if let relDev = relativeDeviation {
                return "\(numberFormatter.string(for: relDev * 100)!) %"
            } else {
                return naString
            }
        }
    }
}

// MARK - Statistical Simple Calculations

public extension Collection where Element: FloatingPoint {
    
    func stats() -> EWSStats<Element> {
        let sortedSelf = sorted()
        let sum = self.sum()
        let mean = self.mean(sum: sum)
        let median = self.median(sorted: sortedSelf)
        let min = self.min(sorted: sortedSelf)
        let max = self.max(sorted: sortedSelf)
        let stDev = self.standardDeviation(mean: mean)
        let relDev = self.relativeDeviation(stDev: stDev, mean: mean)
        return EWSStats(sum: sum, min: min, max: max, mean: mean, median: median, standardDeviation: stDev, relativeDeviation: relDev)
    }
    
    func sum() -> Element {
        return self.reduce(0, +)
    }
    
    func mean(sum: Element? = nil) -> Element? {
        guard count > 0 else { return nil }
        let sum = sum ?? self.sum()
        return sum / Element(count)
    }
    
    func min(sorted: [Element]? = nil) -> Element? {
        let sorted = sorted ?? self.sorted()
        return sorted.first
    }
    
    func max(sorted: [Element]? = nil) -> Element? {
        let sorted = sorted ?? self.sorted()
        return sorted.last
    }
    
    func median(sorted: [Element]? = nil) -> Element? {
        guard count > 0 else { return nil }
        let sorted = sorted ?? self.sorted()
        if sorted.count % 2 == 0 {
            return (sorted[sorted.count / 2] + sorted[sorted.count / 2 - 1]) / 2
        } else {
            return sorted[(sorted.count - 1) / 2]
        }
    }
    
    func standardDeviation(mean: Element? = nil) -> Element? {
        guard count > 1 else { return nil }
        let mean = mean ?? self.mean()!
        let variance = self.reduce(0, { $0 + ($1 - mean) * ($1 - mean) })
        return sqrt(variance / (Element(count) - 1))
    }
    
    func relativeDeviation(stDev: Element? = nil, mean: Element? = nil) -> Element? {
        guard let stDev = stDev ?? standardDeviation() else { return nil }
        let mean = mean ?? self.mean()!
        return stDev / mean
    }
}
