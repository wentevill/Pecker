import XCTest
@testable import NowTimeline

final class SmokeTests: XCTestCase {
    func testAppModuleLoads() {
        XCTAssertEqual(AppIdentity.displayName, "Now Timeline")
    }
}
