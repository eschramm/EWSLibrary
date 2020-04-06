//
//  File.swift
//  EWSLibrary_iOSTests
//
//  Created by Eric Schramm on 4/5/20.
//  Copyright © 2020 eware. All rights reserved.
//

import XCTest
@testable import EWSLibrary

class iOSTests: XCTestCase {
    
    override func setUp() {
        super.setUp()
        // Put setup code here. This method is called before the invocation of each test method in the class.
    }
    
    override func tearDown() {
        // Put teardown code here. This method is called after the invocation of each test method in the class.
        super.tearDown()
    }
    
    func realTruesRandomizationTrial(trueProbability: Double) -> Double {
        let trialCount = 10_000
        var trueCount = 0
        for _ in 0..<trialCount {
            if randomBool(withTrueProbability: trueProbability) {
                trueCount += 1
            }
        }
        return Double(trueCount) / Double(trialCount)
    }
    
    func testAlwaysRandomization() {
        let testRun = realTruesRandomizationTrial(trueProbability: 1)
        //XCTAssertLessThan(fabs(testRun - 1), 0.0000001)
        XCTAssertEqual(testRun, 1)
    }
    
    func testNeverRandomization() {
        let testRun = realTruesRandomizationTrial(trueProbability: 0)
        //XCTAssertLessThan(fabs(testRun - 0), 0.0000001)
        XCTAssertEqual(testRun, 0)
    }

    func testSometimesRandomization() {
        for probability in [0.25, 0.5, 0.75] {
            let testRun = realTruesRandomizationTrial(trueProbability: probability)
            XCTAssertLessThan(fabs(testRun - probability), 0.01)
        }
    }
}
