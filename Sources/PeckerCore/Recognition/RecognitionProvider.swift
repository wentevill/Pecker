import Foundation

public protocol RecognitionProvider: Sendable {
    func recognize(_ input: RecognitionInput) async throws -> RecognitionResult
}

public struct LocalModelRecognitionProvider: RecognitionProvider {
    public init() {}

    public func recognize(_ input: RecognitionInput) async throws -> RecognitionResult {
        throw RecognitionError.localModelUnavailable
    }
}

