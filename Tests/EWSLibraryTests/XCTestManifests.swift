import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(EWSLibraryTests.allTests),
    ]
}
#endif
