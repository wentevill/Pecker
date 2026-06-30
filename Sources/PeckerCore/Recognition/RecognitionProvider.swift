import Foundation

public protocol RecognitionProvider: Sendable {
    func recognize(_ input: RecognitionInput) async throws -> RecognitionResult
}
