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
