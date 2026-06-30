import Foundation

struct RecognitionFunctionProperty: Sendable, Equatable {
    let name: String
    let description: String
}

enum RecognitionFunctionContract: String, CaseIterable, Sendable {
    case classifyEvent = "classify_event"
    case fillMeeting = "fill_meeting_event"
    case fillTask = "fill_task_event"
    case fillFlight = "fill_flight_event"
    case fillTrain = "fill_train_event"
    case fillTravel = "fill_travel_event"
    case fillInterview = "fill_interview_event"
    case fillDeadline = "fill_deadline_event"
    case fillGeneric = "fill_generic_event"

    var name: String { rawValue }

    static let fieldContracts: [RecognitionFunctionContract] =
        TimelineKind.allCases.map(fieldContract(for:))

    static func fieldContract(
        for kind: TimelineKind
    ) -> RecognitionFunctionContract {
        switch kind {
        case .meeting: .fillMeeting
        case .task: .fillTask
        case .flight: .fillFlight
        case .train: .fillTrain
        case .travel: .fillTravel
        case .interview: .fillInterview
        case .deadline: .fillDeadline
        case .unknown: .fillGeneric
        }
    }

    var kind: TimelineKind? {
        switch self {
        case .classifyEvent: nil
        case .fillMeeting: .meeting
        case .fillTask: .task
        case .fillFlight: .flight
        case .fillTrain: .train
        case .fillTravel: .travel
        case .fillInterview: .interview
        case .fillDeadline: .deadline
        case .fillGeneric: .unknown
        }
    }

    var properties: [RecognitionFunctionProperty] {
        switch self {
        case .classifyEvent:
            [.init(
                name: "kind",
                description: "\u{6700}\u{7b26}\u{5408}\u{8f93}\u{5165}\u{7684}\u{4e8b}\u{4ef6}\u{7c7b}\u{578b}。"
            )]
        case .fillTrain:
            Self.properties([
                ("title", "\u{7b80}\u{6d01}\u{7968}\u{636e}\u{6807}\u{9898}。"),
                ("trainNumber", "\u{8f66}\u{6b21}，\u{4f8b}\u{5982} C5788。"),
                ("departureStation", "\u{51fa}\u{53d1}\u{7ad9}\u{5b8c}\u{6574}\u{540d}\u{79f0}。"),
                ("arrivalStation", "\u{5230}\u{8fbe}\u{7ad9}\u{5b8c}\u{6574}\u{540d}\u{79f0}。"),
                ("departureDateTime", "\u{5e26} UTC \u{504f}\u{79fb}\u{7684} ISO-8601 \u{51fa}\u{53d1}\u{65f6}\u{95f4}。"),
                ("arrivalDateTime", "\u{5e26} UTC \u{504f}\u{79fb}\u{7684} ISO-8601 \u{5230}\u{8fbe}\u{65f6}\u{95f4}。"),
                ("carriageNumber", "\u{8f66}\u{53a2}\u{53f7}。"),
                ("seatNumber", "\u{5ea7}\u{4f4d}\u{53f7}。"),
                ("checkInGate", "\u{68c0}\u{7968}\u{53e3}。"),
                ("passengerName", "\u{4e58}\u{8f66}\u{4eba}。"),
                ("ticketNumber", "\u{7968}\u{53f7}。"),
                ("orderNumber", "\u{8ba2}\u{5355}\u{53f7}。"),
                ("seatClass", "\u{5e2d}\u{522b}。"),
                ("price", "\u{7968}\u{4ef7}，\u{4ec5}\u{586b}\u{5199}\u{6570}\u{5b57}\u{548c}\u{539f}\u{59cb}\u{8d27}\u{5e01}\u{7b26}\u{53f7}。"),
                ("ticketType", "\u{6210}\u{4eba}\u{7968}、\u{513f}\u{7ae5}\u{7968}\u{7b49}\u{7968}\u{79cd}。"),
                ("purchaseTime", "\u{5e26} UTC \u{504f}\u{79fb}\u{7684} ISO-8601 \u{8d2d}\u{7968}\u{65f6}\u{95f4}。"),
                ("purchaseChannel", "\u{8d2d}\u{7968}\u{6e20}\u{9053}。"),
                ("idCardLastDigits", "\u{8bc1}\u{4ef6}\u{53f7}\u{53ef}\u{89c1}\u{5c3e}\u{53f7}。"),
                ("location", "\u{989d}\u{5916}\u{6709}\u{7528}\u{5730}\u{70b9}。"),
                ("notes", "\u{7528}\u{6237}\u{9700}\u{8981}\u{67e5}\u{770b}\u{6216}\u{51c6}\u{5907}\u{7684}\u{7cbe}\u{70bc}\u{5907}\u{6ce8}。")
            ])
        case .fillFlight:
            Self.properties([
                ("title", "\u{7b80}\u{6d01}\u{822a}\u{73ed}\u{6807}\u{9898}。"),
                ("flightNumber", "\u{822a}\u{73ed}\u{53f7}。"),
                ("carrier", "\u{822a}\u{7a7a}\u{516c}\u{53f8}\u{6216}\u{627f}\u{8fd0}\u{65b9}。"),
                ("departureAirport", "\u{51fa}\u{53d1}\u{673a}\u{573a}\u{540d}\u{79f0}。"),
                ("departureAirportCode", "\u{51fa}\u{53d1}\u{673a}\u{573a}\u{4ee3}\u{7801}。"),
                ("arrivalAirport", "\u{5230}\u{8fbe}\u{673a}\u{573a}\u{540d}\u{79f0}。"),
                ("arrivalAirportCode", "\u{5230}\u{8fbe}\u{673a}\u{573a}\u{4ee3}\u{7801}。"),
                ("departureDateTime", "\u{5e26} UTC \u{504f}\u{79fb}\u{7684} ISO-8601 \u{51fa}\u{53d1}\u{65f6}\u{95f4}。"),
                ("arrivalDateTime", "\u{5e26} UTC \u{504f}\u{79fb}\u{7684} ISO-8601 \u{5230}\u{8fbe}\u{65f6}\u{95f4}。"),
                ("terminal", "\u{822a}\u{7ad9}\u{697c}。"),
                ("gate", "\u{767b}\u{673a}\u{53e3}。"),
                ("seat", "\u{5ea7}\u{4f4d}。"),
                ("bookingReference", "\u{9884}\u{8ba2}\u{7f16}\u{53f7}。"),
                ("passengerName", "\u{4e58}\u{673a}\u{4eba}。"),
                ("cabin", "\u{8231}\u{4f4d}。"),
                ("status", "\u{822a}\u{73ed}\u{72b6}\u{6001}。"),
                ("location", "\u{989d}\u{5916}\u{6709}\u{7528}\u{5730}\u{70b9}。"),
                ("notes", "\u{7528}\u{6237}\u{9700}\u{8981}\u{67e5}\u{770b}\u{6216}\u{51c6}\u{5907}\u{7684}\u{7cbe}\u{70bc}\u{5907}\u{6ce8}。")
            ])
        case .fillMeeting:
            Self.properties(Self.commonTimedProperties + [
                ("participants", "\u{53c2}\u{4f1a}\u{4eba}。"),
                ("organizer", "\u{7ec4}\u{7ec7}\u{8005}。"),
                ("meetingLink", "\u{4f1a}\u{8bae}\u{94fe}\u{63a5}。"),
                ("agenda", "\u{8bae}\u{7a0b}。")
            ])
        case .fillInterview:
            Self.properties(Self.commonTimedProperties + [
                ("company", "\u{516c}\u{53f8}。"),
                ("role", "\u{5c97}\u{4f4d}。"),
                ("interviewer", "\u{9762}\u{8bd5}\u{5b98}。"),
                ("meetingLink", "\u{9762}\u{8bd5}\u{94fe}\u{63a5}。"),
                ("contact", "\u{8054}\u{7cfb}\u{4eba}\u{6216}\u{8054}\u{7cfb}\u{65b9}\u{5f0f}。")
            ])
        case .fillTask:
            Self.properties([
                ("title", "\u{9700}\u{8981}\u{6267}\u{884c}\u{7684}\u{4efb}\u{52a1}\u{6807}\u{9898}。"),
                ("dueDateTime", "\u{5e26} UTC \u{504f}\u{79fb}\u{7684} ISO-8601 \u{6267}\u{884c}\u{6216}\u{5230}\u{671f}\u{65f6}\u{95f4}。"),
                ("eventDate", "\u{4ec5}\u{6709}\u{65e5}\u{671f}\u{65f6}\u{586b}\u{5199} YYYY-MM-DD。"),
                ("location", "\u{6267}\u{884c}\u{5730}\u{70b9}。"),
                ("priority", "\u{4f18}\u{5148}\u{7ea7}。"),
                ("assignee", "\u{6267}\u{884c}\u{4eba}。"),
                ("project", "\u{6240}\u{5c5e}\u{9879}\u{76ee}。"),
                ("notes", "\u{6267}\u{884c}\u{4efb}\u{52a1}\u{9700}\u{8981}\u{7684}\u{7cbe}\u{70bc}\u{8bf4}\u{660e}。")
            ])
        case .fillDeadline:
            Self.properties([
                ("title", "\u{622a}\u{6b62}\u{4e8b}\u{9879}\u{6807}\u{9898}。"),
                ("deadlineDateTime", "\u{5e26} UTC \u{504f}\u{79fb}\u{7684} ISO-8601 \u{622a}\u{6b62}\u{65f6}\u{95f4}。"),
                ("eventDate", "\u{4ec5}\u{6709}\u{65e5}\u{671f}\u{65f6}\u{586b}\u{5199} YYYY-MM-DD。"),
                ("owner", "\u{8d1f}\u{8d23}\u{4eba}。"),
                ("project", "\u{6240}\u{5c5e}\u{9879}\u{76ee}。"),
                ("submissionChannel", "\u{63d0}\u{4ea4}\u{6e20}\u{9053}。"),
                ("location", "\u{5730}\u{70b9}。"),
                ("notes", "\u{63d0}\u{4ea4}\u{6240}\u{9700}\u{7684}\u{7cbe}\u{70bc}\u{8bf4}\u{660e}。")
            ])
        case .fillTravel:
            Self.properties([
                ("title", "\u{884c}\u{7a0b}\u{6807}\u{9898}。"),
                ("startDateTime", "\u{5e26} UTC \u{504f}\u{79fb}\u{7684} ISO-8601 \u{5f00}\u{59cb}\u{65f6}\u{95f4}。"),
                ("eventDate", "\u{4ec5}\u{6709}\u{65e5}\u{671f}\u{65f6}\u{586b}\u{5199} YYYY-MM-DD。"),
                ("endDateTime", "\u{5e26} UTC \u{504f}\u{79fb}\u{7684} ISO-8601 \u{7ed3}\u{675f}\u{65f6}\u{95f4}。"),
                ("origin", "\u{51fa}\u{53d1}\u{5730}。"),
                ("destination", "\u{76ee}\u{7684}\u{5730}。"),
                ("bookingReference", "\u{9884}\u{8ba2}\u{7f16}\u{53f7}。"),
                ("accommodation", "\u{4f4f}\u{5bbf}\u{4fe1}\u{606f}。"),
                ("transport", "\u{4ea4}\u{901a}\u{65b9}\u{5f0f}。"),
                ("address", "\u{5730}\u{5740}。"),
                ("location", "\u{4e3b}\u{8981}\u{5730}\u{70b9}。"),
                ("notes", "\u{7528}\u{6237}\u{9700}\u{8981}\u{67e5}\u{770b}\u{6216}\u{51c6}\u{5907}\u{7684}\u{7cbe}\u{70bc}\u{5907}\u{6ce8}。")
            ])
        case .fillGeneric:
            Self.properties([
                ("title", "\u{4ece}\u{8f93}\u{5165}\u{5185}\u{5bb9}\u{5f62}\u{6210}\u{7684}\u{7b80}\u{6d01}\u{4e8b}\u{4ef6}\u{6807}\u{9898}。"),
                ("startDateTime", "\u{5e26} UTC \u{504f}\u{79fb}\u{7684} ISO-8601 \u{5f00}\u{59cb}\u{65f6}\u{95f4}。"),
                ("eventDate", "\u{4ec5}\u{6709}\u{65e5}\u{671f}\u{65f6}\u{586b}\u{5199} YYYY-MM-DD。"),
                ("endDateTime", "\u{5e26} UTC \u{504f}\u{79fb}\u{7684} ISO-8601 \u{7ed3}\u{675f}\u{65f6}\u{95f4}。"),
                ("destination", "\u{76ee}\u{7684}\u{5730}。"),
                ("location", "\u{5730}\u{70b9}。"),
                ("notes", "\u{7528}\u{6237}\u{9700}\u{8981}\u{67e5}\u{770b}\u{6216}\u{51c6}\u{5907}\u{7684}\u{7cbe}\u{70bc}\u{5907}\u{6ce8}。")
            ])
        }
    }

    var requiredProperties: [String] {
        properties.map(\.name)
    }

    var additionalProperties: Bool { false }

    var toolDefinition: [String: Any] {
        let propertyDefinitions: [String: [String: Any]]
        if self == .classifyEvent {
            propertyDefinitions = [
                "kind": [
                    "type": "string",
                    "enum": TimelineKind.allCases.map(\.rawValue),
                    "description": properties[0].description
                ]
            ]
        } else {
            propertyDefinitions = Dictionary(
                uniqueKeysWithValues: properties.map { property in
                    (
                        property.name,
                        [
                            "type": ["string", "null"],
                            "description": property.description
                        ] as [String: Any]
                    )
                }
            )
        }

        return [
            "type": "function",
            "function": [
                "name": name,
                "description": functionDescription,
                "strict": true,
                "parameters": [
                    "type": "object",
                    "properties": propertyDefinitions,
                    "required": requiredProperties,
                    "additionalProperties": false
                ] as [String: Any]
            ] as [String: Any]
        ]
    }

    private var functionDescription: String {
        switch self {
        case .classifyEvent:
            "\u{5224}\u{65ad}\u{8f93}\u{5165}\u{5bf9}\u{5e94}\u{7684}\u{4e00}\u{4e2a}\u{4e8b}\u{4ef6}\u{7c7b}\u{578b}。"
        case .fillMeeting:
            "\u{586b}\u{5199}\u{4f1a}\u{8bae}\u{4e8b}\u{4ef6}\u{5b57}\u{6bb5}，\u{7f3a}\u{5931}\u{503c}\u{4f20} null。"
        case .fillTask:
            "\u{586b}\u{5199}\u{4efb}\u{52a1}\u{4e8b}\u{4ef6}\u{5b57}\u{6bb5}，\u{7f3a}\u{5931}\u{503c}\u{4f20} null。"
        case .fillFlight:
            "\u{586b}\u{5199}\u{822a}\u{73ed}\u{4e8b}\u{4ef6}\u{5b57}\u{6bb5}，\u{7f3a}\u{5931}\u{503c}\u{4f20} null。"
        case .fillTrain:
            "\u{586b}\u{5199}\u{706b}\u{8f66}\u{7968}\u{4e8b}\u{4ef6}\u{5b57}\u{6bb5}，\u{7f3a}\u{5931}\u{503c}\u{4f20} null。"
        case .fillTravel:
            "\u{586b}\u{5199}\u{4e00}\u{822c}\u{884c}\u{7a0b}\u{5b57}\u{6bb5}，\u{7f3a}\u{5931}\u{503c}\u{4f20} null。"
        case .fillInterview:
            "\u{586b}\u{5199}\u{9762}\u{8bd5}\u{4e8b}\u{4ef6}\u{5b57}\u{6bb5}，\u{7f3a}\u{5931}\u{503c}\u{4f20} null。"
        case .fillDeadline:
            "\u{586b}\u{5199}\u{622a}\u{6b62}\u{4e8b}\u{9879}\u{5b57}\u{6bb5}，\u{7f3a}\u{5931}\u{503c}\u{4f20} null。"
        case .fillGeneric:
            "\u{586b}\u{5199}\u{65e0}\u{6cd5}\u{5f52}\u{5165}\u{4e13}\u{7528}\u{7c7b}\u{578b}\u{7684}\u{901a}\u{7528}\u{4e8b}\u{4ef6}\u{5b57}\u{6bb5}，\u{7f3a}\u{5931}\u{503c}\u{4f20} null。"
        }
    }

    private static let commonTimedProperties: [(String, String)] = [
        ("title", "\u{4e8b}\u{4ef6}\u{6807}\u{9898}。"),
        ("startDateTime", "\u{5e26} UTC \u{504f}\u{79fb}\u{7684} ISO-8601 \u{5f00}\u{59cb}\u{65f6}\u{95f4}。"),
        ("endDateTime", "\u{5e26} UTC \u{504f}\u{79fb}\u{7684} ISO-8601 \u{7ed3}\u{675f}\u{65f6}\u{95f4}。"),
        ("location", "\u{5730}\u{70b9}。"),
        ("notes", "\u{7528}\u{6237}\u{9700}\u{8981}\u{67e5}\u{770b}\u{6216}\u{51c6}\u{5907}\u{7684}\u{7cbe}\u{70bc}\u{5907}\u{6ce8}。")
    ]

    private static func properties(
        _ values: [(String, String)]
    ) -> [RecognitionFunctionProperty] {
        values.map(RecognitionFunctionProperty.init(name:description:))
    }
}
