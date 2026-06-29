import Foundation

public enum RecognitionPipelineStage: String, Codable, Sendable, Equatable {
    case classification
    case extraction
    case verification
    case validation

    public var displayName: String {
        switch self {
        case .classification: "类型识别"
        case .extraction: "字段提取"
        case .verification: "结果核对"
        case .validation: "必要字段检查"
        }
    }
}

public struct RecognitionPipelineFailure: Error, Sendable, Equatable {
    public let stage: RecognitionPipelineStage
    public let reason: String
    public let technicalSummary: String?
    public let httpStatus: Int?
    public let serviceCode: String?
    public let serviceMessage: String?
    public let missingFields: [String]
    public let responseExcerpt: String?

    public init(
        stage: RecognitionPipelineStage,
        reason: String,
        technicalSummary: String?,
        httpStatus: Int?,
        serviceCode: String?,
        serviceMessage: String?,
        missingFields: [String],
        responseExcerpt: String?
    ) {
        self.stage = stage
        self.reason = reason
        self.technicalSummary = technicalSummary
        self.httpStatus = httpStatus
        self.serviceCode = serviceCode
        self.serviceMessage = serviceMessage
        self.missingFields = missingFields
        self.responseExcerpt = responseExcerpt.map {
            String($0.prefix(Self.responseExcerptLimit))
        }
    }

    public var technicalDetails: String {
        var lines = ["阶段：\(stage.displayName)"]
        if let httpStatus {
            lines.append("HTTP \(httpStatus)")
        }
        if let serviceCode, !serviceCode.isEmpty {
            lines.append("错误码：\(serviceCode)")
        }
        if let serviceMessage, !serviceMessage.isEmpty {
            lines.append("服务信息：\(serviceMessage)")
        }
        if let technicalSummary, !technicalSummary.isEmpty {
            lines.append("详情：\(technicalSummary)")
        }
        if !missingFields.isEmpty {
            lines.append("缺少字段：\(missingFields.joined(separator: "、"))")
        }
        if let responseExcerpt, !responseExcerpt.isEmpty {
            lines.append("响应：\(responseExcerpt)")
        }
        return Self.redact(lines.joined(separator: "\n"))
    }

    private static let responseExcerptLimit = 800

    private static func redact(_ value: String) -> String {
        let replacements = [
            (#"(?i)Bearer\s+[^\s\n"]+"#, "Bearer [REDACTED]"),
            (#"sk-[A-Za-z0-9_-]+"#, "[REDACTED]"),
            (#"data:image/[^;,\s]+;base64,[A-Za-z0-9+/=]+"#, "data:image/[REDACTED]")
        ]
        return replacements.reduce(value) { partial, replacement in
            partial.replacingOccurrences(
                of: replacement.0,
                with: replacement.1,
                options: .regularExpression
            )
        }
    }
}

public struct RecognitionKindSchema: Sendable, Equatable {
    public struct Requirement: Sendable, Equatable {
        public let label: String
        public let alternatives: [[String]]

        public init(label: String, alternatives: [[String]]) {
            self.label = label
            self.alternatives = alternatives
        }
    }

    public let kind: TimelineKind
    public let requirements: [Requirement]
    public let optionalFields: [String]
    public let extractionGuidance: String

    public init(
        kind: TimelineKind,
        requirements: [Requirement],
        optionalFields: [String],
        extractionGuidance: String
    ) {
        self.kind = kind
        self.requirements = requirements
        self.optionalFields = optionalFields
        self.extractionGuidance = extractionGuidance
    }

    public func missingFields(in fields: [String: String]) -> [String] {
        requirements.compactMap { requirement in
            let isSatisfied = requirement.alternatives.contains { alternative in
                alternative.allSatisfy { hasValue(for: $0, in: fields) }
            }
            return isSatisfied ? nil : requirement.label
        }
    }

    public static func schema(for kind: TimelineKind) -> RecognitionKindSchema {
        let preciseStart = [
            ["startDateTime"],
            ["departureDateTime"],
            ["eventDate", "startTime"],
            ["eventDate", "departureTime"]
        ]
        let dateOrTime = preciseStart + [["eventDate"], ["date"]]
        let taskDateOrTime = [
            ["dueDateTime"],
            ["executionDateTime"]
        ] + dateOrTime
        let deadlineDateOrTime = [
            ["deadlineDateTime"],
            ["dueDateTime"]
        ] + dateOrTime
        let title = [["title"], ["eventTitle"]]

        switch kind {
        case .train:
            return .init(
                kind: kind,
                requirements: [
                    .init(label: "车次", alternatives: [["trainNumber"]]),
                    .init(label: "出发站", alternatives: [["departureStation"]]),
                    .init(label: "到达站", alternatives: [["arrivalStation"]]),
                    .init(label: "出发日期时间", alternatives: preciseStart)
                ],
                optionalFields: [
                    "arrivalDateTime", "arrivalDate", "arrivalTime",
                    "carriageNumber", "seatNumber", "checkInGate",
                    "passengerName", "ticketNumber", "orderNumber",
                    "seatClass", "price"
                ],
                extractionGuidance: "按中国铁路票面识别车次、发站、到站、开车时间；保留可见站名后缀。"
            )
        case .flight:
            return .init(
                kind: kind,
                requirements: [
                    .init(label: "航班号", alternatives: [["flightNumber"]]),
                    .init(
                        label: "出发地",
                        alternatives: [["departureAirport"], ["departureAirportCode"]]
                    ),
                    .init(
                        label: "到达地",
                        alternatives: [["arrivalAirport"], ["arrivalAirportCode"]]
                    ),
                    .init(label: "出发日期时间", alternatives: preciseStart)
                ],
                optionalFields: [
                    "carrier", "arrivalDateTime", "terminal", "gate", "seat",
                    "bookingReference", "passengerName", "cabin", "status"
                ],
                extractionGuidance: "区分航班号、机场、航站楼、登机口和座位，不把订单号当作航班号。"
            )
        case .meeting:
            return genericSchema(
                kind: kind,
                requirements: [
                    .init(label: "标题", alternatives: title),
                    .init(label: "开始日期时间", alternatives: preciseStart)
                ],
                optionalFields: [
                    "endDateTime", "location", "participants", "organizer",
                    "meetingLink", "agenda", "notes"
                ]
            )
        case .interview:
            return genericSchema(
                kind: kind,
                requirements: [
                    .init(label: "标题", alternatives: title),
                    .init(label: "开始日期时间", alternatives: preciseStart)
                ],
                optionalFields: [
                    "endDateTime", "company", "role", "interviewer", "location",
                    "meetingLink", "contact", "notes"
                ]
            )
        case .task:
            return genericSchema(
                kind: kind,
                requirements: [
                    .init(label: "标题", alternatives: title),
                    .init(
                        label: "执行日期",
                        alternatives: taskDateOrTime
                    )
                ],
                optionalFields: [
                    "endDateTime", "location", "priority", "assignee", "project", "notes"
                ]
            )
        case .deadline:
            return genericSchema(
                kind: kind,
                requirements: [
                    .init(label: "标题", alternatives: title),
                    .init(
                        label: "截止日期",
                        alternatives: deadlineDateOrTime
                    )
                ],
                optionalFields: [
                    "location", "owner", "project", "submissionChannel", "notes"
                ]
            )
        case .travel:
            return genericSchema(
                kind: kind,
                requirements: [
                    .init(
                        label: "标题或目的地",
                        alternatives: title + [["destination"]]
                    ),
                    .init(label: "开始日期", alternatives: dateOrTime)
                ],
                optionalFields: [
                    "endDateTime", "origin", "location", "bookingReference",
                    "accommodation", "transport", "address", "notes"
                ]
            )
        case .unknown:
            return genericSchema(
                kind: kind,
                requirements: [
                    .init(
                        label: "事件内容",
                        alternatives: title + [["destination"]]
                    ),
                    .init(label: "日期或时间", alternatives: dateOrTime)
                ],
                optionalFields: ["location", "notes"]
            )
        }
    }

    private static func genericSchema(
        kind: TimelineKind,
        requirements: [Requirement],
        optionalFields: [String]
    ) -> RecognitionKindSchema {
        .init(
            kind: kind,
            requirements: requirements,
            optionalFields: optionalFields,
            extractionGuidance: "只保留用户可执行的事件信息；备注精炼且不包含识别依据。"
        )
    }

    private func hasValue(for key: String, in fields: [String: String]) -> Bool {
        fields.contains { candidate, value in
            candidate.caseInsensitiveCompare(key) == .orderedSame
                && !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
}
