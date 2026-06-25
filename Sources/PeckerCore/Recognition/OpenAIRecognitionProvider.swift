import Foundation

public struct OpenAIRecognitionProvider: RecognitionProvider {
    public struct Configuration: Sendable, Equatable {
        public let host: String
        public let apiKey: String
        public let model: String

        public init(host: String, apiKey: String, model: String) {
            self.host = host
            self.apiKey = apiKey
            self.model = model
        }
    }

    public let configuration: Configuration

    public init(configuration: Configuration) {
        self.configuration = configuration
    }

    public func recognize(_ input: RecognitionInput) async throws -> RecognitionResult {
        throw RecognitionError.networkExecutionNotImplemented
    }

    public func makeRequest(for input: RecognitionInput) throws -> URLRequest {
        guard let url = endpointURL(host: configuration.host),
              !configuration.apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              !configuration.model.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        else {
            throw RecognitionError.invalidConfiguration
        }

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.setValue("Bearer \(configuration.apiKey)", forHTTPHeaderField: "Authorization")
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.httpBody = try JSONSerialization.data(
            withJSONObject: requestBody(for: input),
            options: [.sortedKeys, .withoutEscapingSlashes]
        )
        return request
    }

    private func endpointURL(host: String) -> URL? {
        let trimmed = host.trimmingCharacters(in: .whitespacesAndNewlines)
        guard var components = URLComponents(string: trimmed) else {
            return nil
        }
        let path = components.path.trimmingCharacters(in: CharacterSet(charactersIn: "/"))
        components.path = "/" + ([path, "v1/responses"].filter { !$0.isEmpty }.joined(separator: "/"))
        return components.url
    }

    private func requestBody(for input: RecognitionInput) throws -> [String: Any] {
        [
            "model": configuration.model,
            "store": false,
            "input": [
                [
                    "role": "system",
                    "content": [
                        [
                            "type": "input_text",
                            "text": systemPrompt
                        ]
                    ]
                ],
                [
                    "role": "user",
                    "content": try userContent(for: input)
                ]
            ],
            "text": [
                "format": [
                    "type": "json_schema",
                    "name": "pecker_event_template_payload",
                    "strict": true,
                    "schema": payloadSchema
                ]
            ]
        ]
    }

    private func userContent(for input: RecognitionInput) throws -> [[String: Any]] {
        var content: [[String: Any]] = [
            [
                "type": "input_text",
                "text": inputDescription(for: input)
            ]
        ]

        if let imageData = input.imageData {
            content.append([
                "type": "input_image",
                "image_url": "data:\(mimeType(for: input.filename));base64,\(imageData.base64EncodedString())"
            ])
        }

        return content
    }

    private func inputDescription(for input: RecognitionInput) -> String {
        let fields = [
            "source": input.source.rawValue,
            "id": input.id,
            "sourceIdentifier": input.sourceIdentifier ?? "",
            "title": input.title ?? "",
            "location": input.location ?? "",
            "notes": input.notes ?? "",
            "filename": input.filename ?? ""
        ]
        return fields
            .map { "\($0.key): \($0.value)" }
            .sorted()
            .joined(separator: "\n")
    }

    private func mimeType(for filename: String?) -> String {
        guard let filename = filename?.lowercased() else {
            return "image/jpeg"
        }
        if filename.hasSuffix(".png") {
            return "image/png"
        }
        if filename.hasSuffix(".webp") {
            return "image/webp"
        }
        return "image/jpeg"
    }

    private var systemPrompt: String {
        """
        You are Pecker's event recognition engine. Convert calendar, reminder, imported image, or camera image content into one structured event template payload. Prefer concrete ticket/pass/meeting/deadline fields when visible. Return only JSON that matches the schema.
        """
    }

    private var payloadSchema: [String: Any] {
        [
            "type": "object",
            "additionalProperties": false,
            "required": ["kind", "fields"],
            "properties": [
                "kind": [
                    "type": "string",
                    "enum": TimelineKind.allCases.map(\.rawValue)
                ],
                "fields": [
                    "type": "object",
                    "additionalProperties": [
                        "type": "string"
                    ]
                ]
            ]
        ]
    }
}
