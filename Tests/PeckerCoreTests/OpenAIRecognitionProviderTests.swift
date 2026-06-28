import Foundation
import Testing
@testable import PeckerCore

@Test func openAIProviderBuildsChatCompletionsRequestWithCustomHostModelAndKey() throws {
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

    #expect(request.url?.absoluteString == "https://proxy.example.com/base/v1/chat/completions")
    #expect(request.httpMethod == "POST")
    #expect(request.value(forHTTPHeaderField: "Authorization") == "Bearer sk-test")
    #expect(request.value(forHTTPHeaderField: "Content-Type") == "application/json")

    let body = try #require(request.httpBody)
    let json = try #require(
        JSONSerialization.jsonObject(with: body) as? [String: Any]
    )
    #expect(json["model"] as? String == "gpt-test")
    #expect(json["messages"] != nil)
    #expect(json["response_format"] == nil)
    #expect(String(data: body, encoding: .utf8)?.contains("G123 上海虹桥") == true)
    #expect(String(data: body, encoding: .utf8)?.contains("1970-01-01T00:16:40.000Z") == true)
    #expect(String(data: body, encoding: .utf8)?.contains("1970-01-01T00:33:20.000Z") == true)
    #expect(String(data: body, encoding: .utf8)?.contains("isAllDay: false") == true)
    #expect(String(data: body, encoding: .utf8)?.contains("event recognition skill") == true)
    #expect(String(data: body, encoding: .utf8)?.contains("unknown") == true)
}

@Test func openAIProviderDoesNotDuplicateV1InHost() throws {
    let provider = OpenAIRecognitionProvider(
        configuration: .init(
            host: "https://proxy.example.com/v1/",
            apiKey: "sk-test",
            model: "gpt-test"
        )
    )

    let request = try provider.makeRequest(
        for: .reminder(
            sourceIdentifier: "reminder-1",
            title: "提交报告",
            dueDate: nil,
            endDate: nil,
            notes: nil
        )
    )

    #expect(request.url?.absoluteString == "https://proxy.example.com/v1/chat/completions")
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
    #expect(text.contains("image_url"))
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
    #expect(request.url?.absoluteString == "https://api.openai.com/v1/chat/completions")
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

@Test func openAIProviderRecognizesChatCompletionsPayload() async throws {
    let client = StubRecognitionHTTPClient(
        data: Data(
            """
            {
              "choices": [
                {
                  "message": {
                    "content": "{\\"kind\\":\\"train\\",\\"fields\\":{\\"seatNumber\\":\\"03A\\"}}"
                  }
                }
              ]
            }
            """.utf8
        ),
        statusCode: 200
    )
    let provider = OpenAIRecognitionProvider(
        configuration: .init(
            host: "https://api.openai.com/v1",
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

@Test func openAIProviderReportsWhenModelDoesNotSupportImages() async throws {
    let client = StubRecognitionHTTPClient(
        data: Data(
            """
            {"object":"error","message":"model MiniMax-M3 do not support image params","code":400}
            """.utf8
        ),
        statusCode: 400
    )
    let provider = OpenAIRecognitionProvider(
        configuration: .init(
            host: "https://openapi.coreshub.cn/v1",
            apiKey: "sk-test",
            model: "MiniMax-M3"
        ),
        httpClient: client
    )

    do {
        _ = try await provider.recognize(
            .importedImage(
                id: "image-1",
                imageData: Data([0xFF, 0xD8, 0xFF]),
                filename: "ticket.jpg"
            )
        )
        Issue.record("Expected image-model compatibility error")
    } catch {
        #expect(error as? RecognitionError == .imageInputUnsupported)
    }
}

@Test func openAIProviderDiscardsReasoningBeforeFinalJSON() async throws {
    let client = StubRecognitionHTTPClient(
        data: Data(
            """
            {
              "choices": [
                {
                  "message": {
                    "content": "<think>模型提示中含有未配对引号 \\" 但不应影响结果</think>\\n\\n{\\"kind\\":\\"train\\",\\"fields\\":{\\"trainNumber\\":\\"G123\\"}}"
                  }
                }
              ]
            }
            """.utf8
        ),
        statusCode: 200
    )
    let provider = OpenAIRecognitionProvider(
        configuration: .init(
            host: "https://api.example.com/v1",
            apiKey: "sk-test",
            model: "vision"
        ),
        httpClient: client
    )

    let result = try await provider.recognize(
        .importedImage(
            id: "image-1",
            imageData: Data([1]),
            filename: "ticket.jpg"
        )
    )

    #expect(result.payload.kind == .train)
    #expect(result.payload.fields["trainNumber"] == "G123")
}

@Test func openAIProviderRejectsTextWithoutFinalJSON() async throws {
    let client = StubRecognitionHTTPClient(
        data: Data(
            """
            {
              "choices": [
                {
                  "message": {
                    "content": "<think>没有发现事件</think>\\n无法识别"
                  }
                }
              ]
            }
            """.utf8
        ),
        statusCode: 200
    )
    let provider = OpenAIRecognitionProvider(
        configuration: .init(
            host: "https://api.example.com/v1",
            apiKey: "sk-test",
            model: "vision"
        ),
        httpClient: client
    )

    await #expect(throws: RecognitionError.invalidResponse) {
        _ = try await provider.recognize(
            .importedImage(
                id: "image-1",
                imageData: Data([1]),
                filename: "ticket.jpg"
            )
        )
    }
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
