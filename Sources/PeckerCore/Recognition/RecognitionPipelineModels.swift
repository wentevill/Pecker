import Foundation

public enum RecognitionPipelineStage: String, Codable, Sendable, Equatable {
    case classification
    case extraction
    case verification
    case validation

    public var displayName: String {
        switch self {
        case .classification: "\u{7c7b}\u{578b}\u{8bc6}\u{522b}"
        case .extraction: "\u{5b57}\u{6bb5}\u{63d0}\u{53d6}"
        case .verification: "\u{7ed3}\u{679c}\u{6838}\u{5bf9}"
        case .validation: "\u{5fc5}\u{8981}\u{5b57}\u{6bb5}\u{68c0}\u{67e5}"
        }
    }
}

public enum RecognitionFailureCode: String, Sendable, Equatable {
    case validationMissingContent
    case imageUnsupported
    case functionCallingUnsupported
    case authenticationFailed
    case rateLimited
    case serviceFailed
    case timedOut
    case offline
    case hostUnreachable
    case networkFailed
    case malformedResponse
    case missingFunctionCall
    case multipleFunctionCalls
    case unexpectedFunctionCall
    case malformedFunctionArguments
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
    public let code: RecognitionFailureCode

    public init(
        stage: RecognitionPipelineStage,
        reason: String,
        technicalSummary: String?,
        httpStatus: Int?,
        serviceCode: String?,
        serviceMessage: String?,
        missingFields: [String],
        responseExcerpt: String?,
        code: RecognitionFailureCode = .serviceFailed
    ) {
        self.stage = stage
        self.reason = reason
        self.technicalSummary = technicalSummary
        self.httpStatus = httpStatus
        self.serviceCode = serviceCode
        self.serviceMessage = serviceMessage
        self.missingFields = missingFields
        self.code = code
        self.responseExcerpt = responseExcerpt.map {
            String($0.prefix(Self.responseExcerptLimit))
        }
    }

    public var technicalDetails: String {
        var lines = ["\u{9636}\u{6bb5}：\(stage.displayName)"]
        if let httpStatus {
            lines.append("HTTP \(httpStatus)")
        }
        if let serviceCode, !serviceCode.isEmpty {
            lines.append("\u{9519}\u{8bef}\u{7801}：\(serviceCode)")
        }
        if let serviceMessage, !serviceMessage.isEmpty {
            lines.append("\u{670d}\u{52a1}\u{4fe1}\u{606f}：\(serviceMessage)")
        }
        if let technicalSummary, !technicalSummary.isEmpty {
            lines.append("\u{8be6}\u{60c5}：\(technicalSummary)")
        }
        if !missingFields.isEmpty {
            lines.append("\u{7f3a}\u{5c11}\u{5b57}\u{6bb5}：\(missingFields.joined(separator: "、"))")
        }
        if let responseExcerpt, !responseExcerpt.isEmpty {
            lines.append("\u{54cd}\u{5e94}：\(responseExcerpt)")
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
                    .init(label: "\u{8f66}\u{6b21}", alternatives: [["trainNumber"]]),
                    .init(label: "\u{51fa}\u{53d1}\u{7ad9}", alternatives: [["departureStation"]]),
                    .init(label: "\u{5230}\u{8fbe}\u{7ad9}", alternatives: [["arrivalStation"]]),
                    .init(label: "\u{51fa}\u{53d1}\u{65e5}\u{671f}\u{65f6}\u{95f4}", alternatives: preciseStart)
                ],
                optionalFields: [
                    "arrivalDateTime", "arrivalDate", "arrivalTime",
                    "carriageNumber", "seatNumber", "checkInGate",
                    "passengerName", "ticketNumber", "orderNumber",
                    "seatClass", "price"
                ],
                extractionGuidance: "\u{6309}\u{4e2d}\u{56fd}\u{94c1}\u{8def}\u{7968}\u{9762}\u{8bc6}\u{522b}\u{8f66}\u{6b21}、\u{53d1}\u{7ad9}、\u{5230}\u{7ad9}、\u{5f00}\u{8f66}\u{65f6}\u{95f4}；\u{4fdd}\u{7559}\u{53ef}\u{89c1}\u{7ad9}\u{540d}\u{540e}\u{7f00}。"
            )
        case .flight:
            return .init(
                kind: kind,
                requirements: [
                    .init(label: "\u{822a}\u{73ed}\u{53f7}", alternatives: [["flightNumber"]]),
                    .init(
                        label: "\u{51fa}\u{53d1}\u{5730}",
                        alternatives: [["departureAirport"], ["departureAirportCode"]]
                    ),
                    .init(
                        label: "\u{5230}\u{8fbe}\u{5730}",
                        alternatives: [["arrivalAirport"], ["arrivalAirportCode"]]
                    ),
                    .init(label: "\u{51fa}\u{53d1}\u{65e5}\u{671f}\u{65f6}\u{95f4}", alternatives: preciseStart)
                ],
                optionalFields: [
                    "carrier", "arrivalDateTime", "terminal", "gate", "seat",
                    "bookingReference", "passengerName", "cabin", "status"
                ],
                extractionGuidance: "\u{533a}\u{5206}\u{822a}\u{73ed}\u{53f7}、\u{673a}\u{573a}、\u{822a}\u{7ad9}\u{697c}、\u{767b}\u{673a}\u{53e3}\u{548c}\u{5ea7}\u{4f4d}，\u{4e0d}\u{628a}\u{8ba2}\u{5355}\u{53f7}\u{5f53}\u{4f5c}\u{822a}\u{73ed}\u{53f7}。"
            )
        case .meeting:
            return genericSchema(
                kind: kind,
                requirements: [
                    .init(label: "\u{6807}\u{9898}", alternatives: title),
                    .init(label: "\u{5f00}\u{59cb}\u{65e5}\u{671f}\u{65f6}\u{95f4}", alternatives: preciseStart)
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
                    .init(label: "\u{6807}\u{9898}", alternatives: title),
                    .init(label: "\u{5f00}\u{59cb}\u{65e5}\u{671f}\u{65f6}\u{95f4}", alternatives: preciseStart)
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
                    .init(label: "\u{6807}\u{9898}", alternatives: title),
                    .init(
                        label: "\u{6267}\u{884c}\u{65e5}\u{671f}",
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
                    .init(label: "\u{6807}\u{9898}", alternatives: title),
                    .init(
                        label: "\u{622a}\u{6b62}\u{65e5}\u{671f}",
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
                        label: "\u{6807}\u{9898}\u{6216}\u{76ee}\u{7684}\u{5730}",
                        alternatives: title + [["destination"]]
                    ),
                    .init(label: "\u{5f00}\u{59cb}\u{65e5}\u{671f}", alternatives: dateOrTime)
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
                        label: "\u{4e8b}\u{4ef6}\u{5185}\u{5bb9}",
                        alternatives: title + [["destination"]]
                    ),
                    .init(label: "\u{65e5}\u{671f}\u{6216}\u{65f6}\u{95f4}", alternatives: dateOrTime)
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
            extractionGuidance: "\u{53ea}\u{4fdd}\u{7559}\u{7528}\u{6237}\u{53ef}\u{6267}\u{884c}\u{7684}\u{4e8b}\u{4ef6}\u{4fe1}\u{606f}；\u{5907}\u{6ce8}\u{7cbe}\u{70bc}\u{4e14}\u{4e0d}\u{5305}\u{542b}\u{8bc6}\u{522b}\u{4f9d}\u{636e}。"
        )
    }

    private func hasValue(for key: String, in fields: [String: String]) -> Bool {
        fields.contains { candidate, value in
            candidate.caseInsensitiveCompare(key) == .orderedSame
                && !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
}
