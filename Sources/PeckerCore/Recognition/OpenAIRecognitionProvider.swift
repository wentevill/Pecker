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
            if input.imageData != nil,
               let message = String(data: data, encoding: .utf8)?.lowercased(),
               message.contains("do not support image") {
                throw RecognitionError.imageInputUnsupported
            }
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
        var pathComponents = components.path
            .split(separator: "/")
            .map(String.init)
        if pathComponents.last != "v1" {
            pathComponents.append("v1")
        }
        pathComponents.append(contentsOf: ["chat", "completions"])
        components.path = "/" + pathComponents.joined(separator: "/")
        return components.url
    }

    private func requestBody(for input: RecognitionInput) throws -> [String: Any] {
        [
            "model": configuration.model,
            "messages": [
                [
                    "role": "system",
                    "content": systemPrompt
                ],
                [
                    "role": "user",
                    "content": try userContent(for: input)
                ]
            ]
        ]
    }

    private func userContent(for input: RecognitionInput) throws -> [[String: Any]] {
        var content: [[String: Any]] = [
            [
                "type": "text",
                "text": inputDescription(for: input)
            ]
        ]

        if let imageData = input.imageData {
            content.append([
                "type": "image_url",
                "image_url": [
                    "url": "data:\(mimeType(for: input.filename));base64,\(imageData.base64EncodedString())"
                ]
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
            "filename": input.filename ?? "",
            "recognitionNow": input.referenceDate.map(Self.iso8601String(from:)) ?? "",
            "timeZone": input.timeZoneIdentifier ?? ""
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

        Prefer concrete visible fields over guesses. Every actionable event must include title and startDateTime using ISO-8601 with an explicit UTC offset, and include endDateTime when an end is visible. Resolve relative words such as 今天、今晚、明天 against recognitionNow in the supplied timeZone. If only a local date and times are visible, also return eventDate as YYYY-MM-DD plus startTime and endTime as HH:mm. Put ordinary event location and details in location and notes. For train tickets, extract trainNumber, departureStation, arrivalStation, departureTime, arrivalTime, carriageNumber, seatNumber, checkInGate, passengerName, ticketNumber, seatClass, and price when visible.

        Return only one JSON object in this exact shape: {"kind":"train","fields":{"trainNumber":"G123"}}. "kind" must be one of meeting, task, flight, train, travel, interview, deadline, or unknown. Every value in "fields" must be a string.
        """
    }

    private func decodePayload(from data: Data) throws -> ExternalEventTemplatePayload {
        guard let envelope = try? JSONDecoder().decode(RecognitionEnvelope.self, from: data) else {
            throw RecognitionError.invalidResponse
        }
        guard let text = envelope.firstText else {
            throw RecognitionError.invalidResponse
        }

        if let payload = decodePayloadObject(text) {
            return payload
        }
        for candidate in jsonObjectCandidates(in: text).reversed() {
            if let payload = decodePayloadObject(candidate) {
                return payload
            }
        }
        throw RecognitionError.invalidResponse
    }

    private func decodePayloadObject(
        _ text: String
    ) -> ExternalEventTemplatePayload? {
        guard let data = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .data(using: .utf8)
        else {
            return nil
        }
        return try? JSONDecoder().decode(ExternalEventTemplatePayload.self, from: data)
    }

    private func jsonObjectCandidates(in text: String) -> [String] {
        var candidates: [String] = []
        var objectStart: String.Index?
        var depth = 0
        var isInsideString = false
        var isEscaped = false

        for index in text.indices {
            let character = text[index]
            if depth == 0 {
                if character == "{" {
                    objectStart = index
                    depth = 1
                }
                continue
            }

            if isInsideString {
                if isEscaped {
                    isEscaped = false
                } else if character == "\\" {
                    isEscaped = true
                } else if character == "\"" {
                    isInsideString = false
                }
                continue
            }

            if character == "\"" {
                isInsideString = true
            } else if character == "{" {
                depth += 1
            } else if character == "}", depth > 0 {
                depth -= 1
                if depth == 0, let startIndex = objectStart {
                    candidates.append(String(text[startIndex...index]))
                    objectStart = nil
                }
            }
        }
        return candidates
    }
}

private struct RecognitionEnvelope: Decodable {
    struct Output: Decodable {
        struct Content: Decodable {
            let text: String?
        }

        let content: [Content]?
    }

    struct Choice: Decodable {
        struct Message: Decodable {
            let content: String?
        }

        let message: Message
    }

    let outputText: String?
    let output: [Output]?
    let choices: [Choice]?

    private enum CodingKeys: String, CodingKey {
        case outputText = "output_text"
        case output
        case choices
    }

    var firstText: String? {
        if let chatContent = choices?
            .lazy
            .compactMap(\.message.content)
            .first(where: { !$0.isEmpty }) {
            return chatContent
        }

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
