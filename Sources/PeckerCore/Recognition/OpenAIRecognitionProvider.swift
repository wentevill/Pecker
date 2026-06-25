import Foundation

public protocol RecognitionHTTPClient: Sendable {
    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse)
}

public struct URLSessionRecognitionHTTPClient: RecognitionHTTPClient {
    private let session: URLSession

    public init(session: URLSession = .shared) {
        self.session = session
    }

    public func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        let (data, response) = try await session.data(for: request)
        guard let httpResponse = response as? HTTPURLResponse else {
            throw RecognitionError.invalidResponse
        }
        return (data, httpResponse)
    }
}

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
    private let httpClient: any RecognitionHTTPClient

    public init(
        configuration: Configuration,
        httpClient: any RecognitionHTTPClient = URLSessionRecognitionHTTPClient()
    ) {
        self.configuration = configuration
        self.httpClient = httpClient
    }

    public func recognize(_ input: RecognitionInput) async throws -> RecognitionResult {
        let request = try makeRequest(for: input)
        let (data, response) = try await httpClient.data(for: request)
        guard (200..<300).contains(response.statusCode) else {
            throw RecognitionError.requestFailed
        }

        let payload = try decodePayload(from: data)
        return RecognitionResult(payload: payload, confidence: nil)
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
            "startDate": input.startDate.map(Self.iso8601String(from:)) ?? "",
            "endDate": input.endDate.map(Self.iso8601String(from:)) ?? "",
            "isAllDay": input.isAllDay ? "true" : "false",
            "location": input.location ?? "",
            "notes": input.notes ?? "",
            "filename": input.filename ?? ""
        ]
        return fields
            .map { "\($0.key): \($0.value)" }
            .sorted()
            .joined(separator: "\n")
    }

    private static func iso8601String(from date: Date) -> String {
        let formatter = ISO8601DateFormatter()
        formatter.formatOptions = [
            .withInternetDateTime,
            .withFractionalSeconds
        ]
        return formatter.string(from: date)
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
        You are Pecker's event recognition skill. Inspect calendar, reminder, imported image, or camera image input and convert it into one structured event template payload for a timeline card.

        If the input image or text does not clearly contain an actionable event, ticket, pass, travel plan, deadline, reminder, or task, return {"kind":"unknown","fields":{}}.

        Prefer concrete visible fields over guesses. For train tickets, extract trainNumber, departureStation, arrivalStation, departureTime, arrivalTime, carriageNumber, seatNumber, checkInGate, passengerName, and ticketNumber when visible.

        Return only JSON that matches the schema.
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

    private func decodePayload(from data: Data) throws -> ExternalEventTemplatePayload {
        let envelope = try JSONDecoder().decode(ResponsesEnvelope.self, from: data)
        guard let text = envelope.firstText else {
            throw RecognitionError.invalidResponse
        }
        guard let jsonData = text.data(using: .utf8) else {
            throw RecognitionError.invalidResponse
        }
        return try JSONDecoder().decode(ExternalEventTemplatePayload.self, from: jsonData)
    }
}

private struct ResponsesEnvelope: Decodable {
    struct Output: Decodable {
        struct Content: Decodable {
            let text: String?
        }

        let content: [Content]?
    }

    let outputText: String?
    let output: [Output]?

    private enum CodingKeys: String, CodingKey {
        case outputText = "output_text"
        case output
    }

    var firstText: String? {
        if let outputText, !outputText.isEmpty {
            return outputText
        }

        return output?
            .lazy
            .compactMap { $0.content }
            .flatMap { $0 }
            .compactMap(\.text)
            .first { !$0.isEmpty }
    }
}
