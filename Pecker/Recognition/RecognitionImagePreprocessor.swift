import Foundation
import UIKit

struct PreparedRecognitionImage: Sendable, Equatable {
    let data: Data
    let filename: String
    let mimeType: String
    let pixelWidth: Int
    let pixelHeight: Int
}

enum RecognitionImagePreparationError: Error, Equatable {
    case decodeFailed
    case encodeFailed
    case exceedsSizeLimit
}

struct RecognitionImagePreprocessor: Sendable {
    let maximumDimension: CGFloat
    let maximumByteCount: Int
    let qualityAttempts: [CGFloat]

    init(
        maximumDimension: CGFloat = 2_048,
        maximumByteCount: Int = 4 * 1_024 * 1_024,
        qualityAttempts: [CGFloat] = [0.82, 0.72, 0.62]
    ) {
        self.maximumDimension = maximumDimension
        self.maximumByteCount = maximumByteCount
        self.qualityAttempts = qualityAttempts
    }

    func prepare(_ data: Data) throws -> PreparedRecognitionImage {
        guard let decoded = UIImage(data: data),
              decoded.size.width > 0,
              decoded.size.height > 0
        else {
            throw RecognitionImagePreparationError.decodeFailed
        }

        let normalized = normalizedImage(decoded)
        for quality in qualityAttempts {
            guard let encoded = normalized.jpegData(
                compressionQuality: quality
            ) else {
                throw RecognitionImagePreparationError.encodeFailed
            }
            if encoded.count <= maximumByteCount {
                return PreparedRecognitionImage(
                    data: encoded,
                    filename: "recognition.jpg",
                    mimeType: "image/jpeg",
                    pixelWidth: Int(normalized.size.width.rounded()),
                    pixelHeight: Int(normalized.size.height.rounded())
                )
            }
        }

        throw RecognitionImagePreparationError.exceedsSizeLimit
    }

    private func normalizedImage(_ image: UIImage) -> UIImage {
        let longestEdge = max(image.size.width, image.size.height)
        let scale = min(1, maximumDimension / longestEdge)
        let target = CGSize(
            width: max(1, (image.size.width * scale).rounded()),
            height: max(1, (image.size.height * scale).rounded())
        )
        let format = UIGraphicsImageRendererFormat()
        format.scale = 1
        format.opaque = true

        return UIGraphicsImageRenderer(size: target, format: format)
            .image { context in
                UIColor.white.setFill()
                context.fill(CGRect(origin: .zero, size: target))
                image.draw(in: CGRect(origin: .zero, size: target))
            }
    }
}
