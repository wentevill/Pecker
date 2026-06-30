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
                description: "最符合输入的事件类型。"
            )]
        case .fillTrain:
            Self.properties([
                ("title", "简洁票据标题。"),
                ("trainNumber", "车次，例如 C5788。"),
                ("departureStation", "出发站完整名称。"),
                ("arrivalStation", "到达站完整名称。"),
                ("departureDateTime", "带 UTC 偏移的 ISO-8601 出发时间。"),
                ("arrivalDateTime", "带 UTC 偏移的 ISO-8601 到达时间。"),
                ("carriageNumber", "车厢号。"),
                ("seatNumber", "座位号。"),
                ("checkInGate", "检票口。"),
                ("passengerName", "乘车人。"),
                ("ticketNumber", "票号。"),
                ("orderNumber", "订单号。"),
                ("seatClass", "席别。"),
                ("price", "票价，仅填写数字和原始货币符号。"),
                ("ticketType", "成人票、儿童票等票种。"),
                ("purchaseTime", "带 UTC 偏移的 ISO-8601 购票时间。"),
                ("purchaseChannel", "购票渠道。"),
                ("idCardLastDigits", "证件号可见尾号。"),
                ("location", "额外有用地点。"),
                ("notes", "用户需要查看或准备的精炼备注。")
            ])
        case .fillFlight:
            Self.properties([
                ("title", "简洁航班标题。"),
                ("flightNumber", "航班号。"),
                ("carrier", "航空公司或承运方。"),
                ("departureAirport", "出发机场名称。"),
                ("departureAirportCode", "出发机场代码。"),
                ("arrivalAirport", "到达机场名称。"),
                ("arrivalAirportCode", "到达机场代码。"),
                ("departureDateTime", "带 UTC 偏移的 ISO-8601 出发时间。"),
                ("arrivalDateTime", "带 UTC 偏移的 ISO-8601 到达时间。"),
                ("terminal", "航站楼。"),
                ("gate", "登机口。"),
                ("seat", "座位。"),
                ("bookingReference", "预订编号。"),
                ("passengerName", "乘机人。"),
                ("cabin", "舱位。"),
                ("status", "航班状态。"),
                ("location", "额外有用地点。"),
                ("notes", "用户需要查看或准备的精炼备注。")
            ])
        case .fillMeeting:
            Self.properties(Self.commonTimedProperties + [
                ("participants", "参会人。"),
                ("organizer", "组织者。"),
                ("meetingLink", "会议链接。"),
                ("agenda", "议程。")
            ])
        case .fillInterview:
            Self.properties(Self.commonTimedProperties + [
                ("company", "公司。"),
                ("role", "岗位。"),
                ("interviewer", "面试官。"),
                ("meetingLink", "面试链接。"),
                ("contact", "联系人或联系方式。")
            ])
        case .fillTask:
            Self.properties([
                ("title", "需要执行的任务标题。"),
                ("dueDateTime", "带 UTC 偏移的 ISO-8601 执行或到期时间。"),
                ("eventDate", "仅有日期时填写 YYYY-MM-DD。"),
                ("location", "执行地点。"),
                ("priority", "优先级。"),
                ("assignee", "执行人。"),
                ("project", "所属项目。"),
                ("notes", "执行任务需要的精炼说明。")
            ])
        case .fillDeadline:
            Self.properties([
                ("title", "截止事项标题。"),
                ("deadlineDateTime", "带 UTC 偏移的 ISO-8601 截止时间。"),
                ("eventDate", "仅有日期时填写 YYYY-MM-DD。"),
                ("owner", "负责人。"),
                ("project", "所属项目。"),
                ("submissionChannel", "提交渠道。"),
                ("location", "地点。"),
                ("notes", "提交所需的精炼说明。")
            ])
        case .fillTravel:
            Self.properties([
                ("title", "行程标题。"),
                ("startDateTime", "带 UTC 偏移的 ISO-8601 开始时间。"),
                ("eventDate", "仅有日期时填写 YYYY-MM-DD。"),
                ("endDateTime", "带 UTC 偏移的 ISO-8601 结束时间。"),
                ("origin", "出发地。"),
                ("destination", "目的地。"),
                ("bookingReference", "预订编号。"),
                ("accommodation", "住宿信息。"),
                ("transport", "交通方式。"),
                ("address", "地址。"),
                ("location", "主要地点。"),
                ("notes", "用户需要查看或准备的精炼备注。")
            ])
        case .fillGeneric:
            Self.properties([
                ("title", "从输入内容形成的简洁事件标题。"),
                ("startDateTime", "带 UTC 偏移的 ISO-8601 开始时间。"),
                ("eventDate", "仅有日期时填写 YYYY-MM-DD。"),
                ("endDateTime", "带 UTC 偏移的 ISO-8601 结束时间。"),
                ("destination", "目的地。"),
                ("location", "地点。"),
                ("notes", "用户需要查看或准备的精炼备注。")
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
            "判断输入对应的一个事件类型。"
        case .fillMeeting:
            "填写会议事件字段，缺失值传 null。"
        case .fillTask:
            "填写任务事件字段，缺失值传 null。"
        case .fillFlight:
            "填写航班事件字段，缺失值传 null。"
        case .fillTrain:
            "填写火车票事件字段，缺失值传 null。"
        case .fillTravel:
            "填写一般行程字段，缺失值传 null。"
        case .fillInterview:
            "填写面试事件字段，缺失值传 null。"
        case .fillDeadline:
            "填写截止事项字段，缺失值传 null。"
        case .fillGeneric:
            "填写无法归入专用类型的通用事件字段，缺失值传 null。"
        }
    }

    private static let commonTimedProperties: [(String, String)] = [
        ("title", "事件标题。"),
        ("startDateTime", "带 UTC 偏移的 ISO-8601 开始时间。"),
        ("endDateTime", "带 UTC 偏移的 ISO-8601 结束时间。"),
        ("location", "地点。"),
        ("notes", "用户需要查看或准备的精炼备注。")
    ]

    private static func properties(
        _ values: [(String, String)]
    ) -> [RecognitionFunctionProperty] {
        values.map(RecognitionFunctionProperty.init(name:description:))
    }
}
