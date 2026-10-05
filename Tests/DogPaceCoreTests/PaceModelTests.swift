import XCTest
@testable import DogPaceCore

final class PaceModelTests: XCTestCase {
    func testPaceChecks() {
        let failures = PaceChecks.failures()
        XCTAssertEqual(failures, [], failures.joined(separator: "\n"))
    }
}
