import XCTest
@testable import EWSLibrary

final class EWSLibraryTests: XCTestCase {
    
    #if os(macOS)
    func testShell() {
        let shell = Shell()
        XCTAssert(shell.outputOf(commandName: "echo", arguments: ["testing the shell"]) == "testing the shell\n")
    }
    #endif
    
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
            XCTAssertLessThan(fabs(testRun - probability), 0.02)
        }
    }

    #if os(macOS)
    static var allTests = [
        ("testShell", testShell),
        ("testAlwaysRandomization", testAlwaysRandomization),
        ("testNeverRandomization", testNeverRandomization),
        ("testSometimeRandomization", testSometimesRandomization)
    ]
    #elseif os(iOS)
    static var allTests = [
        ("testAlwaysRandomization", testAlwaysRandomization),
        ("testNeverRandomization", testNeverRandomization),
        ("testSometimeRandomization", testSometimesRandomization)
    ]
    #endif
}
