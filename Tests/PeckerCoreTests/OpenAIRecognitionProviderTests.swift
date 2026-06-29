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
    } catch let failure as RecognitionPipelineFailure {
        #expect(failure.stage == .classification)
        #expect(failure.reason == "当前模型不支持图片识别")
        #expect(failure.serviceMessage?.contains("do not support image") == true)
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

    do {
        _ = try await provider.recognize(
            .importedImage(
                id: "image-1",
                imageData: Data([1]),
                filename: "ticket.jpg"
            )
        )
        Issue.record("Expected structured decoding failure")
    } catch let failure as RecognitionPipelineFailure {
        #expect(failure.stage == .classification)
        #expect(failure.reason == "识别结果格式异常")
        #expect(failure.responseExcerpt?.contains("无法识别") == true)
    }
}

@Test func openAIProviderRunsThreeStagesAndInjectsDeviceTimeContext() async throws {
    let referenceDate = ISO8601DateFormatter()
        .date(from: "2026-07-03T01:30:00Z")!
    let client = QueuedRecognitionHTTPClient(steps: [
        .response(chatEnvelope(#"{"kind":"train"}"#), 200),
        .response(chatEnvelope(
            #"{"kind":"train","fields":{"departureStation":"上海虹桥站","arrivalStation":"北京南站"}}"#
        ), 200),
        .response(chatEnvelope(
            #"{"kind":"train","fields":{"trainNumber":"G123","departureStation":"上海虹桥站","arrivalStation":"北京南站","startDateTime":"2026-07-03T08:00:00+08:00"}}"#
        ), 200)
    ])
    let provider = OpenAIRecognitionProvider(
        configuration: .init(
            host: "https://api.example.com",
            apiKey: "sk-test",
            model: "vision"
        ),
        httpClient: client
    )
    let result = try await provider.recognize(
        .importedImage(
            id: "ticket",
            imageData: Data([1]),
            filename: "ticket.jpg",
            referenceDate: referenceDate,
            timeZoneIdentifier: "Asia/Shanghai"
        )
    )

    #expect(result.payload.fields["trainNumber"] == "G123")
    let requests = await client.recordedRequests
    #expect(requests.count == 3)
    let bodies = requests.compactMap(\.httpBody).compactMap {
        String(data: $0, encoding: .utf8)
    }
    #expect(bodies[0].contains("类型识别"))
    #expect(bodies[1].contains("字段提取"))
    #expect(bodies[2].contains("结果核对"))
    #expect(bodies.allSatisfy { $0.contains("Asia/Shanghai") })
    #expect(bodies.allSatisfy { $0.contains("+08:00") })
    #expect(bodies.allSatisfy { $0.contains("2026-07-03T09:30:00+08:00") })
}

@Test func openAIProviderLetsVerificationCorrectUnknownToGeneric() async throws {
    let client = QueuedRecognitionHTTPClient(steps: [
        .response(chatEnvelope(#"{"kind":"unknown"}"#), 200),
        .response(chatEnvelope(
            #"{"kind":"unknown","fields":{"title":"社区活动"}}"#
        ), 200),
        .response(chatEnvelope(
            #"{"kind":"unknown","fields":{"title":"社区活动","eventDate":"2026-07-03","notes":"携带报名二维码"}}"#
        ), 200)
    ])
    let provider = OpenAIRecognitionProvider(
        configuration: .init(
            host: "https://api.example.com",
            apiKey: "sk-test",
            model: "vision"
        ),
        httpClient: client
    )

    let result = try await provider.recognize(
        .importedImage(
            id: "generic",
            imageData: Data([1]),
            filename: "poster.jpg"
        )
    )

    #expect(result.payload.kind == .unknown)
    #expect(result.payload.fields["eventDate"] == "2026-07-03")
    #expect(await client.recordedRequests.count == 3)
}

@Test func openAIProviderAcceptsNumericPriceInReportedTrainPayload() async throws {
    let trainPayload = #"""
    {
      "kind": "train",
      "fields": {
        "title": "C5788 成都东站 → 重庆西站",
        "trainNumber": "C5788",
        "departureStation": "成都东站",
        "arrivalStation": "重庆西站",
        "departureDateTime": "2026-06-28T23:00:00+08:00",
        "arrivalDateTime": "2026-06-28T23:30:00+08:00",
        "seatClass": "二等座",
        "carriageNumber": "02",
        "seatNumber": "06D",
        "price": 96.0,
        "ticketType": "成人票",
        "orderNumber": "E123456789"
      }
    }
    """#
    let client = QueuedRecognitionHTTPClient(steps: [
        .response(chatEnvelope(#"{"kind":"train"}"#), 200),
        .response(chatEnvelope(trainPayload), 200),
        .response(chatEnvelope(trainPayload), 200)
    ])
    let provider = OpenAIRecognitionProvider(
        configuration: .init(
            host: "https://api.example.com",
            apiKey: "sk-test",
            model: "vision"
        ),
        httpClient: client
    )

    let result = try await provider.recognize(
        .importedImage(
            id: "ticket",
            imageData: Data([1]),
            filename: "ticket.jpg"
        )
    )

    #expect(result.payload.fields["trainNumber"] == "C5788")
    #expect(result.payload.fields["price"] == "96")
}

@Test func openAIProviderIncludesTextSourceInEveryPipelineStage() async throws {
    let client = QueuedRecognitionHTTPClient(steps: [
        .response(chatEnvelope(#"{"kind":"meeting"}"#), 200),
        .response(chatEnvelope(
            #"{"kind":"meeting","fields":{"title":"设计评审","startDateTime":"2026-07-03T10:00:00+08:00"}}"#
        ), 200),
        .response(chatEnvelope(
            #"{"kind":"meeting","fields":{"title":"设计评审","startDateTime":"2026-07-03T10:00:00+08:00"}}"#
        ), 200)
    ])
    let provider = OpenAIRecognitionProvider(
        configuration: .init(
            host: "https://api.example.com",
            apiKey: "sk-test",
            model: "vision"
        ),
        httpClient: client
    )

    _ = try await provider.recognize(.calendar(
        sourceIdentifier: "meeting-1",
        title: "设计评审",
        startDate: nil,
        endDate: nil,
        isAllDay: false,
        location: "会议室 A",
        notes: "准备交互稿"
    ))

    let bodies = await client.recordedRequests.compactMap(\.httpBody).compactMap {
        String(data: $0, encoding: .utf8)
    }
    #expect(bodies.count == 3)
    #expect(bodies.allSatisfy { $0.contains("设计评审") })
    #expect(bodies.allSatisfy { $0.contains("会议室 A") })
    #expect(bodies.allSatisfy { $0.contains("准备交互稿") })
}

@Test func openAIProviderPreservesVerificationServiceError() async throws {
    let client = QueuedRecognitionHTTPClient(steps: [
        .response(chatEnvelope(#"{"kind":"train"}"#), 200),
        .response(chatEnvelope(#"{"kind":"train","fields":{}}"#), 200),
        .response(Data(
            #"{"error":{"message":"Too many requests","code":"rate_limit"}}"#.utf8
        ), 429)
    ])
    let provider = OpenAIRecognitionProvider(
        configuration: .init(
            host: "https://api.example.com",
            apiKey: "sk-test",
            model: "vision"
        ),
        httpClient: client
    )

    do {
        _ = try await provider.recognize(
            .importedImage(
                id: "ticket",
                imageData: Data([1]),
                filename: "ticket.jpg"
            )
        )
        Issue.record("Expected structured verification failure")
    } catch let failure as RecognitionPipelineFailure {
        #expect(failure.stage == .verification)
        #expect(failure.httpStatus == 429)
        #expect(failure.serviceCode == "rate_limit")
        #expect(failure.serviceMessage == "Too many requests")
        #expect(failure.reason.contains("429"))
    }
}

@Test func openAIProviderPreservesNetworkFailure() async throws {
    let client = QueuedRecognitionHTTPClient(steps: [
        .failure(URLError(.timedOut))
    ])
    let provider = OpenAIRecognitionProvider(
        configuration: .init(
            host: "https://api.example.com",
            apiKey: "sk-test",
            model: "vision"
        ),
        httpClient: client
    )

    do {
        _ = try await provider.recognize(
            .importedImage(
                id: "ticket",
                imageData: Data([1]),
                filename: "ticket.jpg"
            )
        )
        Issue.record("Expected structured network failure")
    } catch let failure as RecognitionPipelineFailure {
        #expect(failure.stage == .classification)
        #expect(failure.reason == "网络连接超时")
        #expect(failure.technicalDetails.contains("NSURLErrorDomain"))
    }
}

private func chatEnvelope(_ content: String) -> Data {
    let envelope = [
        "choices": [
            ["message": ["content": content]]
        ]
    ]
    return try! JSONSerialization.data(withJSONObject: envelope)
}

private actor QueuedRecognitionHTTPClient: RecognitionHTTPClient {
    enum Step: Sendable {
        case response(Data, Int)
        case failure(URLError)
    }

    private var steps: [Step]
    private(set) var recordedRequests: [URLRequest] = []

    init(steps: [Step]) {
        self.steps = steps
    }

    func data(for request: URLRequest) async throws -> (Data, HTTPURLResponse) {
        recordedRequests.append(request)
        guard !steps.isEmpty else {
            throw URLError(.badServerResponse)
        }
        switch steps.removeFirst() {
        case let .response(data, statusCode):
            let response = HTTPURLResponse(
                url: request.url!,
                statusCode: statusCode,
                httpVersion: nil,
                headerFields: nil
            )!
            return (data, response)
        case let .failure(error):
            throw error
        }
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
