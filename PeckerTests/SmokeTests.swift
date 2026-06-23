import XCTest
@testable import Pecker

final class SmokeTests: XCTestCase {
    func testAppModuleLoads() {
        XCTAssertEqual(AppIdentity.displayName, "Pecker")
    }
}
