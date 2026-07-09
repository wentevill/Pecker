import XCTest
@testable import Pecker

final class RecognitionHostValidatorTests: XCTestCase {
    func testAcceptsHTTPSBaseHostsAndProviderPaths() throws {
        XCTAssertEqual(
            try RecognitionHostValidator.validate(
                " https://api.openai.com "
            ),
            "https://api.openai.com"
        )
        XCTAssertEqual(
            try RecognitionHostValidator.validate(
                "https://example.com/openai"
            ),
            "https://example.com/openai"
        )
    }

    func testRejectsUnsafeOrEndpointURLs() {
        let rejected = [
            "http://example.com",
            "https://user:pass@example.com",
            "https://example.com/v1/chat/completions",
            "https://example.com?token=x",
            "https://example.com#fragment"
        ]
        for value in rejected {
            XCTAssertThrowsError(
                try RecognitionHostValidator.validate(value),
                value
            )
        }
    }
}
