import ImageIO
import UIKit
import XCTest
@testable import Pecker

final class RecognitionImagePreprocessorTests: XCTestCase {
    func testPNGBecomesBoundedJPEG() throws {
        let input = try XCTUnwrap(
            solidImage(size: CGSize(width: 4_000, height: 2_000))
                .pngData()
        )

        let output = try RecognitionImagePreprocessor().prepare(input)

        XCTAssertEqual(output.filename, "recognition.jpg")
        XCTAssertEqual(output.mimeType, "image/jpeg")
        XCTAssertLessThanOrEqual(
            max(output.pixelWidth, output.pixelHeight),
            2_048
        )
        XCTAssertLessThanOrEqual(output.data.count, 4 * 1_024 * 1_024)
        XCTAssertEqual(output.data.prefix(3), Data([0xFF, 0xD8, 0xFF]))
    }

    func testUnreadableDataThrowsDecodeFailure() {
        XCTAssertThrowsError(
            try RecognitionImagePreprocessor().prepare(Data([1, 2, 3]))
        ) { error in
            XCTAssertEqual(
                error as? RecognitionImagePreparationError,
                .decodeFailed
            )
        }
    }

    func testOutputThatCannotMeetLimitThrowsSizeError() throws {
        let input = try XCTUnwrap(
            solidImage(size: CGSize(width: 200, height: 200)).pngData()
        )
        let processor = RecognitionImagePreprocessor(
            maximumDimension: 200,
            maximumByteCount: 8,
            qualityAttempts: [0.1]
        )

        XCTAssertThrowsError(try processor.prepare(input)) { error in
            XCTAssertEqual(
                error as? RecognitionImagePreparationError,
                .exceedsSizeLimit
            )
        }
    }

    func testRotatedImageProducesOrientedDimensions() throws {
        let base = solidImage(size: CGSize(width: 1_200, height: 600))
        let rotated = try orientedJPEG(image: base, orientation: .right)

        let output = try RecognitionImagePreprocessor().prepare(rotated)

        XCTAssertEqual(output.pixelWidth, 600)
        XCTAssertEqual(output.pixelHeight, 1_200)
    }

    private func solidImage(size: CGSize) -> UIImage {
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        return UIGraphicsImageRenderer(size: size, format: format).image { context in
            UIColor.systemBlue.setFill()
            context.fill(CGRect(origin: .zero, size: size))
        }
    }

    private func orientedJPEG(
        image: UIImage,
        orientation: CGImagePropertyOrientation
    ) throws -> Data {
        let data = NSMutableData()
        let destination = try XCTUnwrap(
            CGImageDestinationCreateWithData(
                data,
                "public.jpeg" as CFString,
                1,
                nil
            )
        )
        CGImageDestinationAddImage(
            destination,
            try XCTUnwrap(image.cgImage),
            [
                kCGImagePropertyOrientation: orientation.rawValue
            ] as CFDictionary
        )
        XCTAssertTrue(CGImageDestinationFinalize(destination))
        return data as Data
    }
}
