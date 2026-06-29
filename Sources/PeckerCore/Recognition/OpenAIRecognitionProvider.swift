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
        let kind = try decodeKind(from: kindData, stage: .classification)
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
        let candidate = try decodePayload(
            from: extractionData,
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
        let payload = try decodePayload(
            from: verificationData,
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
        return body
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

    private var classificationPrompt: String {
        """
        你是 Pecker 的事件类型识别器。只判断图片或输入的基本类型，不提取字段。
        只返回 JSON：{"kind":"train"}。
        kind 必须是 meeting、task、flight、train、travel、interview、deadline 或 unknown。
        不要输出推理、依据、Markdown 或额外文字。
        """
    }

    private var extractionPrompt: String {
        """
        你是 Pecker 的精确字段提取器。根据指定类型尽可能扫描有效内容。
        缺少可选字段时直接省略，绝不猜测。备注只保留用户需要准备、执行或查看的内容，
        不写 OCR 过程、识别依据、置信度或无关文字。只返回约定 JSON。
        """
    }

    private var verificationPrompt: String {
        """
        你是 Pecker 的最终结果核对器。重新查看原图，核对并直接修正候选 JSON。
        可纠正事件类型、字段、日期、时区和先后顺序。不得虚构不可见信息。
        只返回修正后的 JSON，不输出评论、推理、依据、Markdown 或额外文字。
        """
    }

    private func classificationTask(
        input: RecognitionInput,
        context: PromptContext
    ) -> String {
        """
        阶段：类型识别
        \(context.description)
        输入信息：
        \(inputDescription(for: input))

        Tasks:
        - [ ] 查看全部图片内容。
        - [ ] 判断一个最符合的基本类型。
        - [ ] 无法归入专用类型时返回 unknown，后续仍会尝试通用模板。
        - [ ] 只返回 {"kind":"..."}。
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
        阶段：字段提取
        \(context.description)
        输入信息：
        \(inputDescription(for: input))
        已识别类型：\(kind.rawValue)
        最小必要元素：\(requirements)
        可选字段：\(schema.optionalFields.joined(separator: "、"))
        类型说明：\(schema.extractionGuidance)

        Tasks:
        - [ ] 扫描图片全部区域，但只保留与事件有关的信息。
        - [ ] 优先提取最小必要元素。
        - [ ] 尽可能提取清晰可见的可选字段；缺失字段省略。
        - [ ] 相对日期必须依据 deviceNow 和 deviceTimeZone 转成标准日期。
        - [ ] 精确时间使用带 UTC 偏移的 ISO-8601；仅日期使用 eventDate=YYYY-MM-DD。
        - [ ] 返回 {"kind":"\(kind.rawValue)","fields":{"title":"..."}}。
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
        阶段：结果核对
        \(context.description)
        输入信息：
        \(inputDescription(for: input))
        候选结果：\(candidateText)
        当前类型最小必要元素：\(schema.requirements.map(\.label).joined(separator: "、"))

        Tasks:
        - [ ] 对照原图逐项核对类型和字段。
        - [ ] 修正错字、字段错位、日期、UTC 偏移与跨日关系。
        - [ ] 类型错误时直接更正 kind，并按新类型字段返回。
        - [ ] 删除识别依据、重复内容和无关备注。
        - [ ] 缺失可选字段可以省略，不得猜测。
        - [ ] 返回最终 {"kind":"...","fields":{...}}。
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
        from data: Data,
        stage: RecognitionPipelineStage
    ) throws -> TimelineKind {
        let text = try responseText(from: data, stage: stage)
        for candidate in ([text] + jsonObjectCandidates(in: text).reversed()) {
            if let value = decodeKindObject(candidate) {
                return value
            }
        }
        throw decodingFailure(stage: stage, excerpt: text)
    }

    private func decodePayload(
        from data: Data,
        stage: RecognitionPipelineStage
    ) throws -> ExternalEventTemplatePayload {
        let text = try responseText(from: data, stage: stage)
        if let payload = decodePayloadObject(text) {
            return payload
        }
        for candidate in jsonObjectCandidates(in: text).reversed() {
            if let payload = decodePayloadObject(candidate) {
                return payload
            }
        }
        throw decodingFailure(stage: stage, excerpt: text)
    }

    private func responseText(
        from data: Data,
        stage: RecognitionPipelineStage
    ) throws -> String {
        guard let envelope = try? JSONDecoder().decode(RecognitionEnvelope.self, from: data) else {
            throw decodingFailure(
                stage: stage,
                excerpt: String(data: data, encoding: .utf8)
            )
        }
        guard let text = envelope.firstText else {
            throw decodingFailure(
                stage: stage,
                excerpt: String(data: data, encoding: .utf8)
            )
        }
        return text
    }

    private func decodeKindObject(_ text: String) -> TimelineKind? {
        guard let data = text
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .data(using: .utf8)
        else {
            return nil
        }
        return try? JSONDecoder().decode(KindResponse.self, from: data).kind
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

    private func networkFailure(
        _ error: Error,
        stage: RecognitionPipelineStage
    ) -> RecognitionPipelineFailure {
        let urlError = error as? URLError
        let reason: String
        switch urlError?.code {
        case .timedOut:
            reason = "网络连接超时"
        case .notConnectedToInternet:
            reason = "设备未连接网络"
        case .cannotFindHost, .cannotConnectToHost, .dnsLookupFailed:
            reason = "无法连接识别服务"
        default:
            reason = "网络请求失败"
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
        let reason: String
        if imageUnsupported {
            reason = "当前模型不支持图片识别"
        } else if statusCode == 401 || statusCode == 403 {
            reason = "API 鉴权失败（HTTP \(statusCode)）"
        } else if statusCode == 429 {
            reason = "服务返回 429：请求过于频繁"
        } else {
            reason = "识别服务返回 HTTP \(statusCode)"
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

    private func decodingFailure(
        stage: RecognitionPipelineStage,
        excerpt: String?
    ) -> RecognitionPipelineFailure {
        RecognitionPipelineFailure(
            stage: stage,
            reason: "识别结果格式异常",
            technicalSummary: "服务响应不包含约定的结构化 JSON",
            httpStatus: nil,
            serviceCode: nil,
            serviceMessage: nil,
            missingFields: [],
            responseExcerpt: excerpt
        )
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
