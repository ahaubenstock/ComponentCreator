import XCTest

#if !canImport(ObjectiveC)
public func allTests() -> [XCTestCaseEntry] {
    return [
        testCase(ComponentCreatorTests.allTests),
    ]
}
#endif
