import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(EWSLibraryTests.allTests),
        testCase(CSVTests.allTests)
    ]
}
#endif
