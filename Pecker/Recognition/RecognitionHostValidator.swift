import Foundation

enum RecognitionHostValidationError: Error, Equatable {
    case invalidURL
    case requiresHTTPS
    case containsCredentials
    case containsQueryOrFragment
    case includesCompletionEndpoint
}

enum RecognitionHostValidator {
    static func validate(_ value: String) throws -> String {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard let components = URLComponents(string: trimmed),
              components.host?.isEmpty == false
        else {
            throw RecognitionHostValidationError.invalidURL
        }
        guard components.scheme?.lowercased() == "https" else {
            throw RecognitionHostValidationError.requiresHTTPS
        }
        guard components.user == nil, components.password == nil else {
            throw RecognitionHostValidationError.containsCredentials
        }
        guard components.query == nil, components.fragment == nil else {
            throw RecognitionHostValidationError.containsQueryOrFragment
        }
        let path = components.path.lowercased()
            .trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        guard !path.hasSuffix("chat/completions") else {
            throw RecognitionHostValidationError.includesCompletionEndpoint
        }
        return trimmed.trimmingCharacters(
            in: CharacterSet(charactersIn: "/")
        )
    }
}
