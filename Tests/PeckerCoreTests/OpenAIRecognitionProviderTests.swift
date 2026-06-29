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

@Test func openAIProviderRejectsContentWithoutFunctionCall() async throws {
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
        Issue.record("Expected missing-function-call failure")
    } catch let failure as RecognitionPipelineFailure {
        #expect(failure.stage == .classification)
        #expect(failure.reason == "模型未调用要求的函数")
        #expect(failure.technicalDetails.contains("无法识别"))
    }
}

@Test func openAIProviderRunsThreeStagesAndInjectsDeviceTimeContext() async throws {
    let referenceDate = ISO8601DateFormatter()
        .date(from: "2026-07-03T01:30:00Z")!
    let client = QueuedRecognitionHTTPClient(steps: [
        .response(toolCallEnvelope(
            name: "classify_event",
            arguments: #"{"kind":"train"}"#
        ), 200),
        .response(toolCallEnvelope(
            name: "fill_train_event",
            arguments: #"{"departureStation":"上海虹桥站","arrivalStation":"北京南站"}"#
        ), 200),
        .response(toolCallEnvelope(
            name: "fill_train_event",
            arguments: #"{"trainNumber":"G123","departureStation":"上海虹桥站","arrivalStation":"北京南站","departureDateTime":"2026-07-03T08:00:00+08:00"}"#
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

@Test func openAIProviderSendsMandatoryFunctionToolsForEveryStage() async throws {
    let client = QueuedRecognitionHTTPClient(steps: [
        .response(toolCallEnvelope(
            name: "classify_event",
            arguments: #"{"kind":"task"}"#
        ), 200),
        .response(toolCallEnvelope(
            name: "fill_task_event",
            arguments: #"{"title":"巡逻仓库","dueDateTime":"2026-06-29T23:30:00+08:00"}"#
        ), 200),
        .response(toolCallEnvelope(
            name: "fill_task_event",
            arguments: #"{"title":"巡逻仓库","dueDateTime":"2026-06-29T23:30:00+08:00"}"#
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

    _ = try await provider.recognize(.reminder(
        sourceIdentifier: "patrol",
        title: "今天晚上11点半巡逻仓库",
        dueDate: nil,
        endDate: nil,
        notes: nil
    ))

    let requests = await client.recordedRequests
    #expect(requests.count == 3)
    let classification = try requestJSON(requests[0])
    let extraction = try requestJSON(requests[1])
    let verification = try requestJSON(requests[2])

    #expect(classification["parallel_tool_calls"] as? Bool == false)
    #expect(toolNames(in: classification) == ["classify_event"])
    #expect(forcedFunctionName(in: classification) == "classify_event")

    #expect(extraction["parallel_tool_calls"] as? Bool == false)
    #expect(toolNames(in: extraction) == ["fill_task_event"])
    #expect(forcedFunctionName(in: extraction) == "fill_task_event")

    #expect(verification["parallel_tool_calls"] as? Bool == false)
    #expect(
        Set(toolNames(in: verification))
            == Set(RecognitionFunctionContract.fieldContracts.map(\.name))
    )
    #expect(verification["tool_choice"] as? String == "required")

    for request in requests {
        let body = try requestJSON(request)
        for tool in (body["tools"] as? [[String: Any]]) ?? [] {
            let function = try #require(tool["function"] as? [String: Any])
            #expect(function["strict"] as? Bool == true)
            let parameters = try #require(
                function["parameters"] as? [String: Any]
            )
            #expect(parameters["additionalProperties"] as? Bool == false)
        }
    }
}

@Test func openAIProviderDecodesRequiredFunctionCalls() async throws {
    let client = QueuedRecognitionHTTPClient(steps: [
        .response(toolCallEnvelope(
            name: "classify_event",
            arguments: #"{"kind":"task"}"#
        ), 200),
        .response(toolCallEnvelope(
            name: "fill_task_event",
            arguments: #"{"title":"巡逻仓库","dueDateTime":"2026-06-29T23:30:00+08:00","eventDate":null,"location":"仓库","priority":null,"assignee":null,"project":null,"notes":null}"#
        ), 200),
        .response(toolCallEnvelope(
            name: "fill_task_event",
            arguments: #"{"title":"巡逻仓库","dueDateTime":"2026-06-29T23:30:00+08:00","eventDate":null,"location":"仓库","priority":null,"assignee":null,"project":null,"notes":null}"#
        ), 200)
    ])
    let provider = makeProvider(client: client)

    let result = try await provider.recognize(.reminder(
        sourceIdentifier: "patrol",
        title: "今天晚上11点半巡逻仓库",
        dueDate: nil,
        endDate: nil,
        notes: nil
    ))

    #expect(result.payload.kind == .task)
    #expect(result.payload.fields["title"] == "巡逻仓库")
    #expect(
        result.payload.fields["dueDateTime"]
            == "2026-06-29T23:30:00+08:00"
    )
    #expect(result.payload.fields["priority"] == nil)
}

@Test func openAIProviderDecodesLegacySingleFunctionCalls() async throws {
    let client = QueuedRecognitionHTTPClient(steps: [
        .response(legacyFunctionCallEnvelope(
            name: "classify_event",
            arguments: #"{"kind":"unknown"}"#
        ), 200),
        .response(legacyFunctionCallEnvelope(
            name: "fill_generic_event",
            arguments: #"{"title":"社区活动","startDateTime":null,"eventDate":"2026-07-03","endDateTime":null,"destination":null,"location":null,"notes":null}"#
        ), 200),
        .response(legacyFunctionCallEnvelope(
            name: "fill_generic_event",
            arguments: #"{"title":"社区活动","startDateTime":null,"eventDate":"2026-07-03","endDateTime":null,"destination":null,"location":null,"notes":null}"#
        ), 200)
    ])

    let result = try await makeProvider(client: client).recognize(
        .importedImage(
            id: "poster",
            imageData: Data([1]),
            filename: "poster.jpg"
        )
    )

    #expect(result.payload.kind == .unknown)
    #expect(result.payload.fields["eventDate"] == "2026-07-03")
}

@Test func openAIProviderRejectsMultipleFunctionCalls() async throws {
    let data = multipleToolCallsEnvelope([
        ("classify_event", #"{"kind":"task"}"#),
        ("classify_event", #"{"kind":"meeting"}"#)
    ])
    let client = QueuedRecognitionHTTPClient(steps: [.response(data, 200)])

    do {
        _ = try await makeProvider(client: client).recognize(
            .importedImage(
                id: "multiple",
                imageData: Data([1]),
                filename: "input.jpg"
            )
        )
        Issue.record("Expected multiple-call failure")
    } catch let failure as RecognitionPipelineFailure {
        #expect(failure.stage == .classification)
        #expect(failure.reason == "模型返回了多个函数调用")
        #expect(failure.technicalDetails.contains("classify_event"))
    }
}

@Test func openAIProviderRejectsWrongFunctionForStage() async throws {
    let client = QueuedRecognitionHTTPClient(steps: [
        .response(toolCallEnvelope(
            name: "fill_task_event",
            arguments: #"{"title":"巡逻仓库"}"#
        ), 200)
    ])

    do {
        _ = try await makeProvider(client: client).recognize(
            .importedImage(
                id: "wrong",
                imageData: Data([1]),
                filename: "input.jpg"
            )
        )
        Issue.record("Expected wrong-function failure")
    } catch let failure as RecognitionPipelineFailure {
        #expect(failure.stage == .classification)
        #expect(failure.reason == "模型调用了当前阶段不允许的函数")
        #expect(failure.technicalDetails.contains("fill_task_event"))
    }
}

@Test func openAIProviderRejectsMalformedFunctionArguments() async throws {
    let client = QueuedRecognitionHTTPClient(steps: [
        .response(toolCallEnvelope(
            name: "classify_event",
            arguments: #"{"kind":"#
        ), 200)
    ])

    do {
        _ = try await makeProvider(client: client).recognize(
            .importedImage(
                id: "bad-args",
                imageData: Data([1]),
                filename: "input.jpg"
            )
        )
        Issue.record("Expected malformed-arguments failure")
    } catch let failure as RecognitionPipelineFailure {
        #expect(failure.stage == .classification)
        #expect(failure.reason == "函数参数格式异常")
    }
}

@Test func openAIProviderLetsVerificationCorrectTheEventType() async throws {
    let client = QueuedRecognitionHTTPClient(steps: [
        .response(toolCallEnvelope(
            name: "classify_event",
            arguments: #"{"kind":"unknown"}"#
        ), 200),
        .response(toolCallEnvelope(
            name: "fill_generic_event",
            arguments: #"{"title":"提交材料"}"#
        ), 200),
        .response(toolCallEnvelope(
            name: "fill_task_event",
            arguments: #"{"title":"提交材料","eventDate":"2026-07-03"}"#
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

    #expect(result.payload.kind == .task)
    #expect(result.payload.fields["eventDate"] == "2026-07-03")
    #expect(await client.recordedRequests.count == 3)
}

@Test func openAIProviderAcceptsNumericPriceInReportedTrainPayload() async throws {
    let trainArguments = #"""
    {
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
    """#
    let client = QueuedRecognitionHTTPClient(steps: [
        .response(toolCallEnvelope(
            name: "classify_event",
            arguments: #"{"kind":"train"}"#
        ), 200),
        .response(toolCallEnvelope(
            name: "fill_train_event",
            arguments: trainArguments
        ), 200),
        .response(toolCallEnvelope(
            name: "fill_train_event",
            arguments: trainArguments
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
            filename: "ticket.jpg"
        )
    )

    #expect(result.payload.fields["trainNumber"] == "C5788")
    #expect(result.payload.fields["price"] == "96")
}

@Test func openAIProviderIncludesTextSourceInEveryPipelineStage() async throws {
    let client = QueuedRecognitionHTTPClient(steps: [
        .response(toolCallEnvelope(
            name: "classify_event",
            arguments: #"{"kind":"meeting"}"#
        ), 200),
        .response(toolCallEnvelope(
            name: "fill_meeting_event",
            arguments: #"{"title":"设计评审","startDateTime":"2026-07-03T10:00:00+08:00"}"#
        ), 200),
        .response(toolCallEnvelope(
            name: "fill_meeting_event",
            arguments: #"{"title":"设计评审","startDateTime":"2026-07-03T10:00:00+08:00"}"#
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
        .response(toolCallEnvelope(
            name: "classify_event",
            arguments: #"{"kind":"train"}"#
        ), 200),
        .response(toolCallEnvelope(
            name: "fill_train_event",
            arguments: #"{}"#
        ), 200),
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

private func toolCallEnvelope(name: String, arguments: String) -> Data {
    multipleToolCallsEnvelope([(name, arguments)])
}

private func multipleToolCallsEnvelope(
    _ calls: [(name: String, arguments: String)]
) -> Data {
    let toolCalls: [[String: Any]] = calls.enumerated().map { index, call in
        [
            "id": "call_\(index)",
            "type": "function",
            "function": [
                "name": call.name,
                "arguments": call.arguments
            ]
        ]
    }
    let envelope: [String: Any] = [
        "choices": [
            ["message": ["content": NSNull(), "tool_calls": toolCalls]]
        ]
    ]
    return try! JSONSerialization.data(withJSONObject: envelope)
}

private func legacyFunctionCallEnvelope(
    name: String,
    arguments: String
) -> Data {
    let envelope: [String: Any] = [
        "choices": [
            [
                "message": [
                    "content": NSNull(),
                    "function_call": [
                        "name": name,
                        "arguments": arguments
                    ]
                ]
            ]
        ]
    ]
    return try! JSONSerialization.data(withJSONObject: envelope)
}

private func makeProvider(
    client: any RecognitionHTTPClient
) -> OpenAIRecognitionProvider {
    OpenAIRecognitionProvider(
        configuration: .init(
            host: "https://api.example.com",
            apiKey: "sk-test",
            model: "vision"
        ),
        httpClient: client
    )
}

private func requestJSON(_ request: URLRequest) throws -> [String: Any] {
    let data = try #require(request.httpBody)
    return try #require(
        JSONSerialization.jsonObject(with: data) as? [String: Any]
    )
}

private func toolNames(in body: [String: Any]) -> [String] {
    ((body["tools"] as? [[String: Any]]) ?? []).compactMap { tool in
        (tool["function"] as? [String: Any])?["name"] as? String
    }
}

private func forcedFunctionName(in body: [String: Any]) -> String? {
    guard let choice = body["tool_choice"] as? [String: Any],
          let function = choice["function"] as? [String: Any]
    else {
        return nil
    }
    return function["name"] as? String
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
