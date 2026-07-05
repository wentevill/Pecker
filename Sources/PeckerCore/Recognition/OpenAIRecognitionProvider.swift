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
        let context = PromptContext(input: input)
        let kindData = try await perform(
            input: input,
            stage: .classification,
            systemPrompt: classificationPrompt,
            taskText: classificationTask(input: input, context: context),
            contracts: [.classifyEvent],
            choice: .forced(.classifyEvent)
        )
        let classificationCall = try requiredFunctionCall(
            from: kindData,
            stage: .classification,
            allowed: [.classifyEvent]
        )
        let kind = try decodeKind(
            from: classificationCall,
            stage: .classification
        )
        let schema = RecognitionKindSchema.schema(for: kind)
        let extractionData = try await perform(
            input: input,
            stage: .extraction,
            systemPrompt: extractionPrompt,
            taskText: extractionTask(
                input: input,
                kind: kind,
                schema: schema,
                context: context
            ),
            contracts: [.fieldContract(for: kind)],
            choice: .forced(.fieldContract(for: kind))
        )
        let extractionContract = RecognitionFunctionContract.fieldContract(
            for: kind
        )
        let extractionCall = try requiredFunctionCall(
            from: extractionData,
            stage: .extraction,
            allowed: [extractionContract]
        )
        let candidate = try decodePayload(
            from: extractionCall,
            contract: extractionContract,
            stage: .extraction
        )
        let verificationData = try await perform(
            input: input,
            stage: .verification,
            systemPrompt: verificationPrompt,
            taskText: verificationTask(
                input: input,
                candidate: candidate,
                context: context
            ),
            contracts: RecognitionFunctionContract.fieldContracts,
            choice: .required
        )
        let verificationCall = try requiredFunctionCall(
            from: verificationData,
            stage: .verification,
            allowed: Set(RecognitionFunctionContract.fieldContracts)
        )
        guard let verificationContract = RecognitionFunctionContract(
            rawValue: verificationCall.name
        ) else {
            throw functionCallFailure(
                stage: .verification,
                reason: "\u{6a21}\u{578b}\u{8c03}\u{7528}\u{4e86}\u{5f53}\u{524d}\u{9636}\u{6bb5}\u{4e0d}\u{5141}\u{8bb8}\u{7684}\u{51fd}\u{6570}",
                summary: "\u{51fd}\u{6570}：\(verificationCall.name)"
            )
        }
        let payload = try decodePayload(
            from: verificationCall,
            contract: verificationContract,
            stage: .verification
        )
        return RecognitionResult(payload: payload, confidence: nil)
    }

    public func makeRequest(for input: RecognitionInput) throws -> URLRequest {
        try makeRequest(
            for: input,
            systemPrompt: systemPrompt,
            taskText: inputDescription(for: input)
        )
    }

    private func makeRequest(
        for input: RecognitionInput,
        systemPrompt: String,
        taskText: String,
        contracts: [RecognitionFunctionContract] = [],
        choice: FunctionChoice? = nil
    ) throws -> URLRequest {
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
            withJSONObject: requestBody(
                for: input,
                systemPrompt: systemPrompt,
                taskText: taskText,
                contracts: contracts,
                choice: choice
            ),
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

    private func requestBody(
        for input: RecognitionInput,
        systemPrompt: String,
        taskText: String,
        contracts: [RecognitionFunctionContract],
        choice: FunctionChoice?
    ) throws -> [String: Any] {
        var body: [String: Any] = [
            "model": configuration.model,
            "messages": [
                [
                    "role": "system",
                    "content": systemPrompt
                ],
                [
                    "role": "user",
                    "content": try userContent(for: input, taskText: taskText)
                ]
            ]
        ]
        if !contracts.isEmpty, let choice {
            body["tools"] = contracts.map(\.toolDefinition)
            body["tool_choice"] = choice.jsonValue
            body["parallel_tool_calls"] = false
        }
        if usesAlibabaModelStudio {
            body["enable_thinking"] = false
        }
        return body
    }

    private var usesAlibabaModelStudio: Bool {
        let trimmed = configuration.host.trimmingCharacters(
            in: .whitespacesAndNewlines
        )
        guard let host = URLComponents(string: trimmed)?.host?.lowercased()
        else {
            return false
        }
        return [
            "maas.aliyuncs.com",
            "dashscope.aliyuncs.com"
        ].contains { domain in
            host == domain || host.hasSuffix(".\(domain)")
        }
    }

    private func userContent(
        for input: RecognitionInput,
        taskText: String
    ) throws -> [[String: Any]] {
        var content: [[String: Any]] = [
            [
                "type": "text",
                "text": taskText
            ]
        ]

        if let imageData = input.imageData {
            let mimeType = input.imageMIMEType ?? "image/jpeg"
            guard ["image/jpeg", "image/png", "image/webp"].contains(mimeType)
            else {
                throw RecognitionError.invalidConfiguration
            }
            content.append([
                "type": "image_url",
                "image_url": [
                    "url": "data:\(mimeType);base64,\(imageData.base64EncodedString())"
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

    private var systemPrompt: String {
        """
        You are Pecker's event recognition skill. Inspect calendar, reminder, imported image, or camera image input and convert it into one structured event template payload for a timeline card.

        If the input image or text does not clearly contain an actionable event, ticket, pass, travel plan, deadline, reminder, or task, return {"kind":"unknown","fields":{}}.

        Prefer concrete visible fields over guesses. Every actionable event must include title and startDateTime using ISO-8601 with an explicit UTC offset, and include endDateTime when an end is visible. Resolve relative words such as \u{4eca}\u{5929}、\u{4eca}\u{665a}、\u{660e}\u{5929} against recognitionNow in the supplied timeZone. If only a local date and times are visible, also return eventDate as YYYY-MM-DD plus startTime and endTime as HH:mm. Put ordinary event location and details in location and notes. For train tickets, extract trainNumber, departureStation, arrivalStation, departureTime, arrivalTime, carriageNumber, seatNumber, checkInGate, passengerName, ticketNumber, seatClass, and price when visible.

        Return only one JSON object in this exact shape: {"kind":"train","fields":{"trainNumber":"G123"}}. "kind" must be one of meeting, task, flight, train, travel, interview, deadline, or unknown. Every value in "fields" must be a string.
        """
    }

    private var classificationPrompt: String {
        """
        \u{4f60}\u{662f} Pecker \u{7684}\u{4e8b}\u{4ef6}\u{7c7b}\u{578b}\u{8bc6}\u{522b}\u{5668}。\u{53ea}\u{5224}\u{65ad}\u{56fe}\u{7247}\u{6216}\u{8f93}\u{5165}\u{7684}\u{57fa}\u{672c}\u{7c7b}\u{578b}，\u{4e0d}\u{63d0}\u{53d6}\u{5b57}\u{6bb5}。
        kind \u{5fc5}\u{987b}\u{662f} meeting、task、flight、train、travel、interview、deadline \u{6216} unknown。
        \u{5fc5}\u{987b}\u{8c03}\u{7528} classify_event \u{51fd}\u{6570}\u{63d0}\u{4ea4}\u{7c7b}\u{578b}，\u{4e0d}\u{8981}\u{8f93}\u{51fa}\u{666e}\u{901a}\u{5185}\u{5bb9}、\u{63a8}\u{7406}、\u{4f9d}\u{636e}\u{6216} Markdown。
        """
    }

    private var extractionPrompt: String {
        """
        \u{4f60}\u{662f} Pecker \u{7684}\u{7cbe}\u{786e}\u{5b57}\u{6bb5}\u{63d0}\u{53d6}\u{5668}。\u{6839}\u{636e}\u{6307}\u{5b9a}\u{7c7b}\u{578b}\u{5c3d}\u{53ef}\u{80fd}\u{626b}\u{63cf}\u{6709}\u{6548}\u{5185}\u{5bb9}。
        \u{7f3a}\u{5c11}\u{53ef}\u{9009}\u{5b57}\u{6bb5}\u{65f6}\u{76f4}\u{63a5}\u{7701}\u{7565}，\u{7edd}\u{4e0d}\u{731c}\u{6d4b}。\u{5907}\u{6ce8}\u{53ea}\u{4fdd}\u{7559}\u{7528}\u{6237}\u{9700}\u{8981}\u{51c6}\u{5907}、\u{6267}\u{884c}\u{6216}\u{67e5}\u{770b}\u{7684}\u{5185}\u{5bb9}，
        \u{4e0d}\u{5199} OCR \u{8fc7}\u{7a0b}、\u{8bc6}\u{522b}\u{4f9d}\u{636e}、\u{7f6e}\u{4fe1}\u{5ea6}\u{6216}\u{65e0}\u{5173}\u{6587}\u{5b57}。\u{5fc5}\u{987b}\u{8c03}\u{7528}\u{63d0}\u{4f9b}\u{7684}\u{5b57}\u{6bb5}\u{51fd}\u{6570}\u{63d0}\u{4ea4}\u{7ed3}\u{679c}。
        """
    }

    private var verificationPrompt: String {
        """
        \u{4f60}\u{662f} Pecker \u{7684}\u{6700}\u{7ec8}\u{7ed3}\u{679c}\u{6838}\u{5bf9}\u{5668}。\u{91cd}\u{65b0}\u{67e5}\u{770b}\u{539f}\u{56fe}，\u{6838}\u{5bf9}\u{5e76}\u{76f4}\u{63a5}\u{4fee}\u{6b63}\u{5019}\u{9009} JSON。
        \u{53ef}\u{7ea0}\u{6b63}\u{4e8b}\u{4ef6}\u{7c7b}\u{578b}、\u{5b57}\u{6bb5}、\u{65e5}\u{671f}、\u{65f6}\u{533a}\u{548c}\u{5148}\u{540e}\u{987a}\u{5e8f}。\u{4e0d}\u{5f97}\u{865a}\u{6784}\u{4e0d}\u{53ef}\u{89c1}\u{4fe1}\u{606f}。
        \u{5fc5}\u{987b}\u{8c03}\u{7528}\u{4e00}\u{4e2a}\u{63d0}\u{4f9b}\u{7684}\u{5b57}\u{6bb5}\u{51fd}\u{6570}\u{63d0}\u{4ea4}\u{6700}\u{7ec8}\u{7ed3}\u{679c}，\u{4e0d}\u{8f93}\u{51fa}\u{8bc4}\u{8bba}、\u{63a8}\u{7406}、\u{4f9d}\u{636e}\u{6216} Markdown。
        """
    }

    private func classificationTask(
        input: RecognitionInput,
        context: PromptContext
    ) -> String {
        """
        \u{9636}\u{6bb5}：\u{7c7b}\u{578b}\u{8bc6}\u{522b}
        \(context.description)
        \u{8f93}\u{5165}\u{4fe1}\u{606f}：
        \(inputDescription(for: input))

        Tasks:
        - [ ] \u{67e5}\u{770b}\u{5168}\u{90e8}\u{56fe}\u{7247}\u{5185}\u{5bb9}。
        - [ ] \u{5224}\u{65ad}\u{4e00}\u{4e2a}\u{6700}\u{7b26}\u{5408}\u{7684}\u{57fa}\u{672c}\u{7c7b}\u{578b}。
        - [ ] \u{65e0}\u{6cd5}\u{5f52}\u{5165}\u{4e13}\u{7528}\u{7c7b}\u{578b}\u{65f6}\u{8fd4}\u{56de} unknown，\u{540e}\u{7eed}\u{4ecd}\u{4f1a}\u{5c1d}\u{8bd5}\u{901a}\u{7528}\u{6a21}\u{677f}。
        - [ ] \u{5fc5}\u{987b}\u{8c03}\u{7528} classify_event \u{63d0}\u{4ea4}\u{552f}\u{4e00}\u{7c7b}\u{578b}。
        """
    }

    private func extractionTask(
        input: RecognitionInput,
        kind: TimelineKind,
        schema: RecognitionKindSchema,
        context: PromptContext
    ) -> String {
        let requirements = schema.requirements
            .map(\.label)
            .joined(separator: "、")
        return """
        \u{9636}\u{6bb5}：\u{5b57}\u{6bb5}\u{63d0}\u{53d6}
        \(context.description)
        \u{8f93}\u{5165}\u{4fe1}\u{606f}：
        \(inputDescription(for: input))
        \u{5df2}\u{8bc6}\u{522b}\u{7c7b}\u{578b}：\(kind.rawValue)
        \u{6700}\u{5c0f}\u{5fc5}\u{8981}\u{5143}\u{7d20}：\(requirements)
        \u{53ef}\u{9009}\u{5b57}\u{6bb5}：\(schema.optionalFields.joined(separator: "、"))
        \u{7c7b}\u{578b}\u{8bf4}\u{660e}：\(schema.extractionGuidance)

        Tasks:
        - [ ] \u{626b}\u{63cf}\u{56fe}\u{7247}\u{5168}\u{90e8}\u{533a}\u{57df}，\u{4f46}\u{53ea}\u{4fdd}\u{7559}\u{4e0e}\u{4e8b}\u{4ef6}\u{6709}\u{5173}\u{7684}\u{4fe1}\u{606f}。
        - [ ] \u{4f18}\u{5148}\u{63d0}\u{53d6}\u{6700}\u{5c0f}\u{5fc5}\u{8981}\u{5143}\u{7d20}。
        - [ ] \u{5c3d}\u{53ef}\u{80fd}\u{63d0}\u{53d6}\u{6e05}\u{6670}\u{53ef}\u{89c1}\u{7684}\u{53ef}\u{9009}\u{5b57}\u{6bb5}；\u{7f3a}\u{5931}\u{5b57}\u{6bb5}\u{7701}\u{7565}。
        - [ ] \u{76f8}\u{5bf9}\u{65e5}\u{671f}\u{5fc5}\u{987b}\u{4f9d}\u{636e} deviceNow \u{548c} deviceTimeZone \u{8f6c}\u{6210}\u{6807}\u{51c6}\u{65e5}\u{671f}。
        - [ ] \u{7cbe}\u{786e}\u{65f6}\u{95f4}\u{4f7f}\u{7528}\u{5e26} UTC \u{504f}\u{79fb}\u{7684} ISO-8601；\u{4ec5}\u{65e5}\u{671f}\u{4f7f}\u{7528} eventDate=YYYY-MM-DD。
        - [ ] \u{5fc5}\u{987b}\u{8c03}\u{7528}\u{63d0}\u{4f9b}\u{7684} \(RecognitionFunctionContract.fieldContract(for: kind).name) \u{51fd}\u{6570}。
        """
    }

    private func verificationTask(
        input: RecognitionInput,
        candidate: ExternalEventTemplatePayload,
        context: PromptContext
    ) -> String {
        let candidateText = (try? JSONEncoder().encode(candidate))
            .flatMap { String(data: $0, encoding: .utf8) } ?? "{}"
        let schema = RecognitionKindSchema.schema(for: candidate.kind)
        return """
        \u{9636}\u{6bb5}：\u{7ed3}\u{679c}\u{6838}\u{5bf9}
        \(context.description)
        \u{8f93}\u{5165}\u{4fe1}\u{606f}：
        \(inputDescription(for: input))
        \u{5019}\u{9009}\u{7ed3}\u{679c}：\(candidateText)
        \u{5f53}\u{524d}\u{7c7b}\u{578b}\u{6700}\u{5c0f}\u{5fc5}\u{8981}\u{5143}\u{7d20}：\(schema.requirements.map(\.label).joined(separator: "、"))

        Tasks:
        - [ ] \u{5bf9}\u{7167}\u{539f}\u{56fe}\u{9010}\u{9879}\u{6838}\u{5bf9}\u{7c7b}\u{578b}\u{548c}\u{5b57}\u{6bb5}。
        - [ ] \u{4fee}\u{6b63}\u{9519}\u{5b57}、\u{5b57}\u{6bb5}\u{9519}\u{4f4d}、\u{65e5}\u{671f}、UTC \u{504f}\u{79fb}\u{4e0e}\u{8de8}\u{65e5}\u{5173}\u{7cfb}。
        - [ ] \u{7c7b}\u{578b}\u{9519}\u{8bef}\u{65f6}\u{76f4}\u{63a5}\u{66f4}\u{6b63} kind，\u{5e76}\u{6309}\u{65b0}\u{7c7b}\u{578b}\u{5b57}\u{6bb5}\u{8fd4}\u{56de}。
        - [ ] \u{5220}\u{9664}\u{8bc6}\u{522b}\u{4f9d}\u{636e}、\u{91cd}\u{590d}\u{5185}\u{5bb9}\u{548c}\u{65e0}\u{5173}\u{5907}\u{6ce8}。
        - [ ] \u{7f3a}\u{5931}\u{53ef}\u{9009}\u{5b57}\u{6bb5}\u{53ef}\u{4ee5}\u{7701}\u{7565}，\u{4e0d}\u{5f97}\u{731c}\u{6d4b}。
        - [ ] \u{5fc5}\u{987b}\u{8c03}\u{7528}\u{4e14}\u{53ea}\u{8c03}\u{7528}\u{4e00}\u{4e2a}\u{6700}\u{5339}\u{914d}\u{7c7b}\u{578b}\u{7684}\u{5b57}\u{6bb5}\u{51fd}\u{6570}。
        """
    }

    private func perform(
        input: RecognitionInput,
        stage: RecognitionPipelineStage,
        systemPrompt: String,
        taskText: String,
        contracts: [RecognitionFunctionContract],
        choice: FunctionChoice
    ) async throws -> Data {
        let request = try makeRequest(
            for: input,
            systemPrompt: systemPrompt,
            taskText: taskText,
            contracts: contracts,
            choice: choice
        )
        let data: Data
        let response: HTTPURLResponse
        do {
            (data, response) = try await httpClient.data(for: request)
        } catch let failure as RecognitionPipelineFailure {
            throw failure
        } catch {
            throw networkFailure(error, stage: stage)
        }
        guard (200..<300).contains(response.statusCode) else {
            throw serviceFailure(
                data: data,
                statusCode: response.statusCode,
                stage: stage,
                hasImage: input.imageData != nil
            )
        }
        return data
    }

    private func decodeKind(
        from call: RecognitionFunctionCall,
        stage: RecognitionPipelineStage
    ) throws -> TimelineKind {
        guard let data = call.arguments.data(using: .utf8),
              let response = try? JSONDecoder().decode(
                KindResponse.self,
                from: data
              )
        else {
            throw malformedArgumentsFailure(
                call: call,
                stage: stage
            )
        }
        return response.kind
    }

    private func decodePayload(
        from call: RecognitionFunctionCall,
        contract: RecognitionFunctionContract,
        stage: RecognitionPipelineStage
    ) throws -> ExternalEventTemplatePayload {
        guard let kind = contract.kind,
              let argumentsData = call.arguments.data(using: .utf8),
              let fields = try? JSONSerialization.jsonObject(
                with: argumentsData
              ) as? [String: Any],
              JSONSerialization.isValidJSONObject(fields)
        else {
            throw malformedArgumentsFailure(call: call, stage: stage)
        }
        let object: [String: Any] = [
            "kind": kind.rawValue,
            "fields": fields
        ]
        do {
            return try JSONDecoder().decode(
                ExternalEventTemplatePayload.self,
                from: JSONSerialization.data(withJSONObject: object)
            )
        } catch {
            throw malformedArgumentsFailure(call: call, stage: stage)
        }
    }

    private func requiredFunctionCall(
        from data: Data,
        stage: RecognitionPipelineStage,
        allowed: Set<RecognitionFunctionContract>
    ) throws -> RecognitionFunctionCall {
        guard let envelope = try? JSONDecoder().decode(
            RecognitionEnvelope.self,
            from: data
        ) else {
            throw functionCallFailure(
                stage: stage,
                reason: "\u{51fd}\u{6570}\u{8c03}\u{7528}\u{54cd}\u{5e94}\u{683c}\u{5f0f}\u{5f02}\u{5e38}",
                summary: "\u{670d}\u{52a1}\u{54cd}\u{5e94}\u{65e0}\u{6cd5}\u{6309} Chat Completions \u{683c}\u{5f0f}\u{89e3}\u{7801}",
                excerpt: String(data: data, encoding: .utf8)
            )
        }
        let message = envelope.choices?.first?.message
        let calls: [RecognitionFunctionCall]
        if let toolCalls = message?.toolCalls, !toolCalls.isEmpty {
            calls = toolCalls
                .filter { $0.type == "function" }
                .map(\.function)
        } else if let legacyCall = message?.functionCall {
            calls = [legacyCall]
        } else {
            throw functionCallFailure(
                stage: stage,
                reason: "\u{6a21}\u{578b}\u{672a}\u{8c03}\u{7528}\u{8981}\u{6c42}\u{7684}\u{51fd}\u{6570}",
                summary: "\u{5f53}\u{524d}\u{9636}\u{6bb5}\u{8981}\u{6c42}\u{51fd}\u{6570}\u{8c03}\u{7528}，\u{4f46}\u{54cd}\u{5e94}\u{53ea}\u{5305}\u{542b}\u{666e}\u{901a}\u{5185}\u{5bb9}",
                excerpt: message?.content ?? String(data: data, encoding: .utf8)
            )
        }

        guard calls.count == 1 else {
            throw functionCallFailure(
                stage: stage,
                reason: "\u{6a21}\u{578b}\u{8fd4}\u{56de}\u{4e86}\u{591a}\u{4e2a}\u{51fd}\u{6570}\u{8c03}\u{7528}",
                summary: "\u{51fd}\u{6570}：\(calls.map(\.name).joined(separator: "、"))"
            )
        }
        let call = calls[0]
        guard let contract = RecognitionFunctionContract(
            rawValue: call.name
        ),
              allowed.contains(contract)
        else {
            throw functionCallFailure(
                stage: stage,
                reason: "\u{6a21}\u{578b}\u{8c03}\u{7528}\u{4e86}\u{5f53}\u{524d}\u{9636}\u{6bb5}\u{4e0d}\u{5141}\u{8bb8}\u{7684}\u{51fd}\u{6570}",
                summary: "\u{51fd}\u{6570}：\(call.name)"
            )
        }
        return call
    }

    private func malformedArgumentsFailure(
        call: RecognitionFunctionCall,
        stage: RecognitionPipelineStage
    ) -> RecognitionPipelineFailure {
        functionCallFailure(
            stage: stage,
            reason: "\u{51fd}\u{6570}\u{53c2}\u{6570}\u{683c}\u{5f0f}\u{5f02}\u{5e38}",
            summary: "\u{51fd}\u{6570} \(call.name) \u{7684} arguments \u{4e0d}\u{662f}\u{6709}\u{6548}\u{7684}\u{6807}\u{91cf} JSON \u{5bf9}\u{8c61}",
            excerpt: call.arguments
        )
    }

    private func functionCallFailure(
        stage: RecognitionPipelineStage,
        reason: String,
        summary: String,
        excerpt: String? = nil
    ) -> RecognitionPipelineFailure {
        RecognitionPipelineFailure(
            stage: stage,
            reason: reason,
            technicalSummary: summary,
            httpStatus: nil,
            serviceCode: nil,
            serviceMessage: nil,
            missingFields: [],
            responseExcerpt: excerpt
        )
    }

    private func networkFailure(
        _ error: Error,
        stage: RecognitionPipelineStage
    ) -> RecognitionPipelineFailure {
        let urlError = error as? URLError
        let reason: String
        switch urlError?.code {
        case .timedOut:
            reason = "\u{7f51}\u{7edc}\u{8fde}\u{63a5}\u{8d85}\u{65f6}"
        case .notConnectedToInternet:
            reason = "\u{8bbe}\u{5907}\u{672a}\u{8fde}\u{63a5}\u{7f51}\u{7edc}"
        case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            reason = "\u{65e0}\u{6cd5}\u{8fde}\u{63a5}\u{8bc6}\u{522b}\u{670d}\u{52a1}"
        default:
            reason = "\u{7f51}\u{7edc}\u{8bf7}\u{6c42}\u{5931}\u{8d25}"
        }
        let summary: String
        if let urlError {
            summary = "NSURLErrorDomain \(urlError.errorCode): \(urlError.localizedDescription)"
        } else {
            summary = "\(type(of: error)): \(error.localizedDescription)"
        }
        return RecognitionPipelineFailure(
            stage: stage,
            reason: reason,
            technicalSummary: summary,
            httpStatus: nil,
            serviceCode: nil,
            serviceMessage: nil,
            missingFields: [],
            responseExcerpt: nil
        )
    }

    private func serviceFailure(
        data: Data,
        statusCode: Int,
        stage: RecognitionPipelineStage,
        hasImage: Bool
    ) -> RecognitionPipelineFailure {
        let rawText = String(data: data, encoding: .utf8) ?? ""
        let details = serviceErrorDetails(from: data)
        let lowercased = [
            rawText,
            details.message ?? ""
        ].joined(separator: " ").lowercased()
        let imageUnsupported = hasImage && (
            lowercased.contains("do not support image")
                || lowercased.contains("image input unsupported")
                || lowercased.contains("does not support image")
        )
        let functionCallingUnsupported =
            lowercased.contains("function calling unsupported")
            || lowercased.contains("function calling is not supported")
            || (
                lowercased.contains("tool")
                    && (
                        lowercased.contains("not supported")
                            || lowercased.contains("unsupported")
                    )
            )
        let reason: String
        if imageUnsupported {
            reason = "\u{5f53}\u{524d}\u{6a21}\u{578b}\u{4e0d}\u{652f}\u{6301}\u{56fe}\u{7247}\u{8bc6}\u{522b}"
        } else if functionCallingUnsupported {
            reason = "\u{5f53}\u{524d}\u{6a21}\u{578b}\u{6216}\u{670d}\u{52a1}\u{4e0d}\u{652f}\u{6301}\u{51fd}\u{6570}\u{8c03}\u{7528}"
        } else if statusCode == 401 || statusCode == 403 {
            reason = "API \u{9274}\u{6743}\u{5931}\u{8d25}（HTTP \(statusCode)）"
        } else if statusCode == 429 {
            reason = "\u{670d}\u{52a1}\u{8fd4}\u{56de} 429：\u{8bf7}\u{6c42}\u{8fc7}\u{4e8e}\u{9891}\u{7e41}"
        } else {
            reason = "\u{8bc6}\u{522b}\u{670d}\u{52a1}\u{8fd4}\u{56de} HTTP \(statusCode)"
        }
        return RecognitionPipelineFailure(
            stage: stage,
            reason: reason,
            technicalSummary: nil,
            httpStatus: statusCode,
            serviceCode: details.code,
            serviceMessage: details.message ?? rawText,
            missingFields: [],
            responseExcerpt: nil
        )
    }

    private func serviceErrorDetails(
        from data: Data
    ) -> (code: String?, message: String?) {
        guard let object = try? JSONSerialization.jsonObject(with: data),
              let root = object as? [String: Any]
        else {
            return (nil, nil)
        }
        let details = (root["error"] as? [String: Any]) ?? root
        let code = details["code"].map { String(describing: $0) }
        let message = details["message"] as? String
        return (code, message)
    }

}

private enum FunctionChoice {
    case forced(RecognitionFunctionContract)
    case required

    var jsonValue: Any {
        switch self {
        case let .forced(contract):
            [
                "type": "function",
                "function": ["name": contract.name]
            ] as [String: Any]
        case .required:
            "required"
        }
    }
}

private struct KindResponse: Decodable {
    let kind: TimelineKind
}

private struct PromptContext {
    let now: Date
    let timeZone: TimeZone

    init(input: RecognitionInput) {
        now = input.referenceDate ?? .now
        timeZone = input.timeZoneIdentifier.flatMap(TimeZone.init(identifier:))
            ?? .current
    }

    var description: String {
        let dateFormatter = DateFormatter()
        dateFormatter.calendar = Calendar(identifier: .gregorian)
        dateFormatter.locale = Locale(identifier: "en_US_POSIX")
        dateFormatter.timeZone = timeZone
        dateFormatter.dateFormat = "yyyy-MM-dd'T'HH:mm:ssXXX"

        let offsetFormatter = DateFormatter()
        offsetFormatter.calendar = Calendar(identifier: .gregorian)
        offsetFormatter.locale = Locale(identifier: "en_US_POSIX")
        offsetFormatter.timeZone = timeZone
        offsetFormatter.dateFormat = "XXX"

        return """
        deviceNow: \(dateFormatter.string(from: now))
        deviceTimeZone: \(timeZone.identifier)
        deviceUTCOffset: \(offsetFormatter.string(from: now))
        """
    }
}

private struct RecognitionFunctionCall: Decodable {
    let name: String
    let arguments: String
}

private struct RecognitionEnvelope: Decodable {
    struct Choice: Decodable {
        struct Message: Decodable {
            struct ToolCall: Decodable {
                let type: String
                let function: RecognitionFunctionCall
            }

            let content: String?
            let toolCalls: [ToolCall]?
            let functionCall: RecognitionFunctionCall?

            private enum CodingKeys: String, CodingKey {
                case content
                case toolCalls = "tool_calls"
                case functionCall = "function_call"
            }
        }

        let message: Message
    }

    let choices: [Choice]?
}
