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
            title: "G123 \u{4e0a}\u{6d77}\u{8679}\u{6865} → \u{5317}\u{4eac}\u{5357}",
            startDate: Date(timeIntervalSince1970: 1_000),
            endDate: Date(timeIntervalSince1970: 2_000),
            isAllDay: false,
            location: "\u{68c0}\u{7968}\u{53e3} B7",
            notes: "08\u{8f66} 03A"
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
    #expect(json["enable_thinking"] == nil)
    #expect(String(data: body, encoding: .utf8)?.contains("G123 \u{4e0a}\u{6d77}\u{8679}\u{6865}") == true)
    #expect(String(data: body, encoding: .utf8)?.contains("1970-01-01T00:16:40.000Z") == true)
    #expect(String(data: body, encoding: .utf8)?.contains("1970-01-01T00:33:20.000Z") == true)
    #expect(String(data: body, encoding: .utf8)?.contains("isAllDay: false") == true)
    #expect(String(data: body, encoding: .utf8)?.contains("event recognition skill") == true)
    #expect(String(data: body, encoding: .utf8)?.contains("unknown") == true)
}

@Test func openAIProviderDisablesThinkingForAlibabaModelStudioHosts() throws {
    let provider = OpenAIRecognitionProvider(
        configuration: .init(
            host: "https://llm-example.cn-beijing.maas.aliyuncs.com/compatible-mode/v1",
            apiKey: "sk-test",
            model: "qwen3.7-plus"
        )
    )

    let request = try provider.makeRequest(
        for: .reminder(
            sourceIdentifier: "reminder-1",
            title: "\u{63d0}\u{4ea4}\u{62a5}\u{544a}",
            dueDate: nil,
            endDate: nil,
            notes: nil
        )
    )

    let body = try #require(request.httpBody)
    let json = try #require(
        JSONSerialization.jsonObject(with: body) as? [String: Any]
    )
    #expect(json["enable_thinking"] as? Bool == false)
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
            title: "\u{63d0}\u{4ea4}\u{62a5}\u{544a}",
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

@Test func openAIProviderIncludesOrderedMultiImageInputsAndNarrativeGuidance() throws {
    let provider = OpenAIRecognitionProvider(
        configuration: .init(
            host: "https://api.openai.com",
            apiKey: "sk-test",
            model: "gpt-test"
        )
    )

    let request = try provider.makeRequest(
        for: .importedImages(
            id: "story-1",
            images: [
                RecognitionImageInput(
                    data: Data([0x01]),
                    filename: "checkout.png",
                    mimeType: "image/png"
                ),
                RecognitionImageInput(
                    data: Data([0x02]),
                    filename: "details.webp",
                    mimeType: "image/webp"
                )
            ],
            referenceDate: Date(timeIntervalSince1970: 1_000),
            timeZoneIdentifier: "Asia/Shanghai"
        )
    )

    let body = try #require(request.httpBody)
    let text = try #require(String(data: body, encoding: .utf8))
    #expect(text.components(separatedBy: #""type":"image_url""#).count - 1 == 2)
    #expect(text.contains("data:image/png;base64,AQ=="))
    #expect(text.contains("data:image/webp;base64,Ag=="))
    #expect(text.contains("imageCount: 2"))
    #expect(text.contains("image 1: checkout.png"))
    #expect(text.contains("image 2: details.webp"))
    #expect(text.contains("\u{8fde}\u{7eed}\u{6027}\u{53d9}\u{4e8b}\u{8bc6}\u{522b}"))
    #expect(text.contains("\u{53ea}\u{5bf9}\u{5e94}\u{4e00}\u{4e2a}\u{4e8b}\u{4ef6}"))
}

@Test func openAIProviderUsesExplicitImageMIMEType() throws {
    let provider = OpenAIRecognitionProvider(
        configuration: .init(
            host: "https://example.com",
            apiKey: "key",
            model: "vision"
        )
    )
    let request = try provider.makeRequest(
        for: .importedImage(
            id: "image-1",
            imageData: Data([0xFF, 0xD8, 0xFF]),
            filename: "misleading.png",
            mimeType: "image/jpeg"
        )
    )
    let httpBody = try #require(request.httpBody)
    let body = try #require(String(data: httpBody, encoding: .utf8))

    #expect(body.contains("data:image/jpeg;base64,/9j/"))
    #expect(!body.contains("data:image/png"))
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
        #expect(failure.reason == "\u{5f53}\u{524d}\u{6a21}\u{578b}\u{4e0d}\u{652f}\u{6301}\u{56fe}\u{7247}\u{8bc6}\u{522b}")
        #expect(failure.serviceMessage?.contains("do not support image") == true)
    }
}

@Test func openAIProviderReportsUnsupportedFunctionCalling() async throws {
    let client = StubRecognitionHTTPClient(
        data: Data(
            #"{"error":{"message":"tools are not supported by this model","code":"unsupported_tools"}}"#.utf8
        ),
        statusCode: 400
    )
    let provider = OpenAIRecognitionProvider(
        configuration: .init(
            host: "https://api.example.com",
            apiKey: "sk-test",
            model: "text-only"
        ),
        httpClient: client
    )

    do {
        _ = try await provider.recognize(.reminder(
            sourceIdentifier: "patrol",
            title: "\u{4eca}\u{5929}\u{665a}\u{4e0a}11\u{70b9}\u{534a}\u{5de1}\u{903b}\u{4ed3}\u{5e93}",
            dueDate: nil,
            endDate: nil,
            notes: nil
        ))
        Issue.record("Expected function-calling compatibility failure")
    } catch let failure as RecognitionPipelineFailure {
        #expect(failure.stage == .classification)
        #expect(failure.reason == "\u{5f53}\u{524d}\u{6a21}\u{578b}\u{6216}\u{670d}\u{52a1}\u{4e0d}\u{652f}\u{6301}\u{51fd}\u{6570}\u{8c03}\u{7528}")
        #expect(failure.httpStatus == 400)
        #expect(failure.serviceCode == "unsupported_tools")
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
                    "content": "<think>\u{6ca1}\u{6709}\u{53d1}\u{73b0}\u{4e8b}\u{4ef6}</think>\\n\u{65e0}\u{6cd5}\u{8bc6}\u{522b}"
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
        #expect(failure.reason == "\u{6a21}\u{578b}\u{672a}\u{8c03}\u{7528}\u{8981}\u{6c42}\u{7684}\u{51fd}\u{6570}")
        #expect(failure.technicalDetails.contains("\u{65e0}\u{6cd5}\u{8bc6}\u{522b}"))
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
            arguments: #"{"departureStation":"\#u{4e0a}\#u{6d77}\#u{8679}\#u{6865}\#u{7ad9}","arrivalStation":"\#u{5317}\#u{4eac}\#u{5357}\#u{7ad9}"}"#
        ), 200),
        .response(toolCallEnvelope(
            name: "fill_train_event",
            arguments: #"{"trainNumber":"G123","departureStation":"\#u{4e0a}\#u{6d77}\#u{8679}\#u{6865}\#u{7ad9}","arrivalStation":"\#u{5317}\#u{4eac}\#u{5357}\#u{7ad9}","departureDateTime":"2026-07-03T08:00:00+08:00"}"#
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
    #expect(bodies[0].contains("\u{7c7b}\u{578b}\u{8bc6}\u{522b}"))
    #expect(bodies[1].contains("\u{5b57}\u{6bb5}\u{63d0}\u{53d6}"))
    #expect(bodies[2].contains("\u{7ed3}\u{679c}\u{6838}\u{5bf9}"))
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
            arguments: #"{"title":"\#u{5de1}\#u{903b}\#u{4ed3}\#u{5e93}","dueDateTime":"2026-06-29T23:30:00+08:00"}"#
        ), 200),
        .response(toolCallEnvelope(
            name: "fill_task_event",
            arguments: #"{"title":"\#u{5de1}\#u{903b}\#u{4ed3}\#u{5e93}","dueDateTime":"2026-06-29T23:30:00+08:00"}"#
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
        title: "\u{4eca}\u{5929}\u{665a}\u{4e0a}11\u{70b9}\u{534a}\u{5de1}\u{903b}\u{4ed3}\u{5e93}",
        dueDate: nil,
        endDate: nil,
        notes: nil
    ))

    let requests = await client.recordedRequests
    #expect(requests.count == 3)
    let bodyTexts = requests.compactMap(\.httpBody).compactMap {
        String(data: $0, encoding: .utf8)
    }
    #expect(bodyTexts.allSatisfy { $0.contains("\u{5fc5}\u{987b}\u{8c03}\u{7528}") })
    #expect(bodyTexts.allSatisfy { !$0.contains("\u{53ea}\u{8fd4}\u{56de} {") })
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
            arguments: #"{"title":"\#u{5de1}\#u{903b}\#u{4ed3}\#u{5e93}","dueDateTime":"2026-06-29T23:30:00+08:00","eventDate":null,"location":"\#u{4ed3}\#u{5e93}","priority":null,"assignee":null,"project":null,"notes":null}"#
        ), 200),
        .response(toolCallEnvelope(
            name: "fill_task_event",
            arguments: #"{"title":"\#u{5de1}\#u{903b}\#u{4ed3}\#u{5e93}","dueDateTime":"2026-06-29T23:30:00+08:00","eventDate":null,"location":"\#u{4ed3}\#u{5e93}","priority":null,"assignee":null,"project":null,"notes":null}"#
        ), 200)
    ])
    let provider = makeProvider(client: client)

    let result = try await provider.recognize(.reminder(
        sourceIdentifier: "patrol",
        title: "\u{4eca}\u{5929}\u{665a}\u{4e0a}11\u{70b9}\u{534a}\u{5de1}\u{903b}\u{4ed3}\u{5e93}",
        dueDate: nil,
        endDate: nil,
        notes: nil
    ))

    #expect(result.payload.kind == .task)
    #expect(result.payload.fields["title"] == "\u{5de1}\u{903b}\u{4ed3}\u{5e93}")
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
            arguments: #"{"title":"\#u{793e}\#u{533a}\#u{6d3b}\#u{52a8}","startDateTime":null,"eventDate":"2026-07-03","endDateTime":null,"destination":null,"location":null,"notes":null}"#
        ), 200),
        .response(legacyFunctionCallEnvelope(
            name: "fill_generic_event",
            arguments: #"{"title":"\#u{793e}\#u{533a}\#u{6d3b}\#u{52a8}","startDateTime":null,"eventDate":"2026-07-03","endDateTime":null,"destination":null,"location":null,"notes":null}"#
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
        #expect(failure.reason == "\u{6a21}\u{578b}\u{8fd4}\u{56de}\u{4e86}\u{591a}\u{4e2a}\u{51fd}\u{6570}\u{8c03}\u{7528}")
        #expect(failure.technicalDetails.contains("classify_event"))
    }
}

@Test func openAIProviderRejectsWrongFunctionForStage() async throws {
    let client = QueuedRecognitionHTTPClient(steps: [
        .response(toolCallEnvelope(
            name: "fill_task_event",
            arguments: #"{"title":"\#u{5de1}\#u{903b}\#u{4ed3}\#u{5e93}"}"#
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
        #expect(failure.reason == "\u{6a21}\u{578b}\u{8c03}\u{7528}\u{4e86}\u{5f53}\u{524d}\u{9636}\u{6bb5}\u{4e0d}\u{5141}\u{8bb8}\u{7684}\u{51fd}\u{6570}")
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
        #expect(failure.reason == "\u{51fd}\u{6570}\u{53c2}\u{6570}\u{683c}\u{5f0f}\u{5f02}\u{5e38}")
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
            arguments: #"{"title":"\#u{63d0}\#u{4ea4}\#u{6750}\#u{6599}"}"#
        ), 200),
        .response(toolCallEnvelope(
            name: "fill_task_event",
            arguments: #"{"title":"\#u{63d0}\#u{4ea4}\#u{6750}\#u{6599}","eventDate":"2026-07-03"}"#
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
      "title": "C5788 \#u{6210}\#u{90fd}\#u{4e1c}\#u{7ad9} → \#u{91cd}\#u{5e86}\#u{897f}\#u{7ad9}",
      "trainNumber": "C5788",
      "departureStation": "\#u{6210}\#u{90fd}\#u{4e1c}\#u{7ad9}",
      "arrivalStation": "\#u{91cd}\#u{5e86}\#u{897f}\#u{7ad9}",
      "departureDateTime": "2026-06-28T23:00:00+08:00",
      "arrivalDateTime": "2026-06-28T23:30:00+08:00",
      "seatClass": "\#u{4e8c}\#u{7b49}\#u{5ea7}",
      "carriageNumber": "02",
      "seatNumber": "06D",
      "price": 96.0,
      "ticketType": "\#u{6210}\#u{4eba}\#u{7968}",
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
            arguments: #"{"title":"\#u{8bbe}\#u{8ba1}\#u{8bc4}\#u{5ba1}","startDateTime":"2026-07-03T10:00:00+08:00"}"#
        ), 200),
        .response(toolCallEnvelope(
            name: "fill_meeting_event",
            arguments: #"{"title":"\#u{8bbe}\#u{8ba1}\#u{8bc4}\#u{5ba1}","startDateTime":"2026-07-03T10:00:00+08:00"}"#
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
        title: "\u{8bbe}\u{8ba1}\u{8bc4}\u{5ba1}",
        startDate: nil,
        endDate: nil,
        isAllDay: false,
        location: "\u{4f1a}\u{8bae}\u{5ba4} A",
        notes: "\u{51c6}\u{5907}\u{4ea4}\u{4e92}\u{7a3f}"
    ))

    let bodies = await client.recordedRequests.compactMap(\.httpBody).compactMap {
        String(data: $0, encoding: .utf8)
    }
    #expect(bodies.count == 3)
    #expect(bodies.allSatisfy { $0.contains("\u{8bbe}\u{8ba1}\u{8bc4}\u{5ba1}") })
    #expect(bodies.allSatisfy { $0.contains("\u{4f1a}\u{8bae}\u{5ba4} A") })
    #expect(bodies.allSatisfy { $0.contains("\u{51c6}\u{5907}\u{4ea4}\u{4e92}\u{7a3f}") })
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
        #expect(failure.reason == "\u{7f51}\u{7edc}\u{8fde}\u{63a5}\u{8d85}\u{65f6}")
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
