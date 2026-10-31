import XCTest

/// Prints each test as it starts, so a crash or GPU failure in CI points at the test that caused it.
@objc(TestProgress)
final class TestProgress: NSObject, XCTestObservation {
    override init() {
        super.init()
        XCTestObservationCenter.shared.addTestObserver(self)
    }

    func testCaseWillStart(_ testCase: XCTestCase) {
        print("SKIP-INFO START \(testCase.name)")
        fflush(stdout)
    }
}
