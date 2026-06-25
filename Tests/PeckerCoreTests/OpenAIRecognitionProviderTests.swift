import Foundation
import Testing
@testable import PeckerCore

@Test func openAIProviderBuildsResponsesRequestWithCustomHostModelAndKey() throws {
    let provider = OpenAIRecognitionProvider(
        configuration: .init(
            host: "https://proxy.example.com/base/",
            apiKey: "sk-test",
            model: "gpt-test"
        )
    )

    let request = try provider.makeRequest(
        for: .calendar(
            sourceIdentifier: "calendar-1",
            title: "G123 上海虹桥 → 北京南",
            startDate: Date(timeIntervalSince1970: 1_000),
            endDate: Date(timeIntervalSince1970: 2_000),
            isAllDay: false,
            location: "检票口 B7",
            notes: "08车 03A"
        )
    )

    #expect(request.url?.absoluteString == "https://proxy.example.com/base/v1/responses")
    #expect(request.httpMethod == "POST")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer sk-test")
    #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")

    let body = try #require(request.httpBody)
    let json = try #require(
        JSONSerialization.jsonObject(with: body) as? [String: Any]
    )
    #expect(json["model"] as? String == "gpt-test")
    #expect(json["store"] as? Bool == false)
    #expect(String(data: body, encoding: .utf8)?.contains("G123 上海虹桥") == true)
    #expect(String(data: body, encoding: .utf8)?.contains("1970-01-01T00:16:40.000Z") == true)
    #expect(String(data: body, encoding: .utf8)?.contains("1970-01-01T00:33:20.000Z") == true)
    #expect(String(data: body, encoding: .utf8)?.contains("isAllDay: false") == true)
    #expect(String(data: body, encoding: .utf8)?.contains("json_schema") == true)
}

@Test func openAIProviderIncludesImageInputsAsDataURLs() throws {
    let provider = OpenAIRecognitionProvider(
        configuration: .init(
            host: "https://api.openai.com",
            apiKey: "sk-test",
            model: "gpt-test"
        )
    )

    let request = try provider.makeRequest(
        for: .importedImage(
            id: "image-1",
            imageData: Data([0xFF, 0xD8, 0xFF]),
            filename: "ticket.jpg"
        )
    )

    let body = try #require(request.httpBody)
    let text = try #require(String(data: body, encoding: .utf8))
    #expect(text.contains("input_image"))
    #expect(text.contains("data:image/jpeg;base64,/9j/"))
}

@Test func openAIProviderRecognizesOutputTextPayload() async throws {
    let client = StubRecognitionHTTPClient(
        data: Data(
            """
            {
              "output_text": "{\\"kind\\":\\"train\\",\\"fields\\":{\\"trainNumber\\":\\"G123\\",\\"departureStation\\":\\"上海虹桥\\",\\"arrivalStation\\":\\"北京南\\"}}"
            }
            """.utf8
        ),
        statusCode: 200
    )
    let provider = OpenAIRecognitionProvider(
        configuration: .init(
            host: "https://api.openai.com",
            apiKey: "sk-test",
            model: "gpt-test"
        ),
        httpClient: client
    )

    let result = try await provider.recognize(
        .calendar(
            sourceIdentifier: "calendar-1",
            title: "G123 上海虹桥 → 北京南",
            startDate: nil,
            endDate: nil,
            isAllDay: false,
            location: nil,
            notes: nil
        )
    )

    #expect(result.payload.kind == .train)
    #expect(result.payload.fields["trainNumber"] == "G123")
    let request = try #require(await client.recordedRequest)
    #expect(request.url?.absoluteString == "https://api.openai.com/v1/responses")
}

@Test func openAIProviderRecognizesNestedOutputContentPayload() async throws {
    let client = StubRecognitionHTTPClient(
        data: Data(
            """
            {
              "output": [
                {
                  "content": [
                    {
                      "type": "output_text",
                      "text": "{\\"kind\\":\\"train\\",\\"fields\\":{\\"seatNumber\\":\\"03A\\"}}"
                    }
                  ]
                }
              ]
            }
            """.utf8
        ),
        statusCode: 200
    )
    let provider = OpenAIRecognitionProvider(
        configuration: .init(
            host: "https://api.openai.com",
            apiKey: "sk-test",
            model: "gpt-test"
        ),
        httpClient: client
    )

    let result = try await provider.recognize(
        .reminder(
            sourceIdentifier: "reminder-1",
            title: "火车票",
            dueDate: nil,
            endDate: nil,
            notes: "03A"
        )
    )

    #expect(result.payload.kind == .train)
    #expect(result.payload.fields["seatNumber"] == "03A")
}

private actor StubRecognitionHTTPClient: RecognitionHTTPClient {
    private let data: Data
    private let statusCode: Int
    private(set) var recordedRequest: URLRequest?

    init(data: Data, statusCode: Int) {
        self.data = data
        self.statusCode = statusCode
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        recordedRequest = request
        let response = HTTPURLResponse(
            url: request.url!,
            statusCode: statusCode,
            httpVersion: nil,
            headerFields: nil
        )!
        return (data, response)
    }
}
