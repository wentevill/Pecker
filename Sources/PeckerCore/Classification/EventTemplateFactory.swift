import Foundation

public struct ClassificationInput: Sendable, Equatable {
    public let title: String
    public let location: String?
    public let notes: String?

    public init(title: String, location: String?, notes: String?) {
        self.title = title
        self.location = location
        self.notes = notes
    }

    var joinedText: String {
        [title, location, notes]
            .compactMap { $0?.trimmingCharacters(in: .whitespacesAndNewlines) }
            .filter { !$0.isEmpty }
            .joined(separator: " ")
    }

    var normalizedText: String {
        joinedText.folding(
            options: [.caseInsensitive, .diacriticInsensitive],
            locale: .current
        )
    }
}

public struct ExternalEventTemplatePayload: Sendable, Equatable, Codable {
    public let kind: TimelineKind
    public let fields: [String: String]

    public init(kind: TimelineKind, fields: [String: String]) {
        self.kind = kind
        self.fields = fields
    }
}

public enum TimelineEventTemplate: Sendable, Equatable, Hashable, Codable {
    case trainTicket(TrainTicketTemplate)
    case generic(GenericEventTemplate)

    public var kind: TimelineKind {
        switch self {
        case .trainTicket:
            .train
        case let .generic(event):
            event.kind
        }
    }

    public var presentation: EventTemplatePresentation {
        switch self {
        case let .trainTicket(ticket):
            ticket.presentation
        case let .generic(event):
            event.presentation
        }
    }
}

public struct EventTemplatePresentation: Sendable, Equatable, Hashable, Codable {
    public enum Style: String, Sendable, Equatable, Hashable, Codable {
        case trainTicket
        case generic
    }

    public struct Field: Sendable, Equatable, Hashable, Codable {
        public let label: String
        public let value: String

        public init(label: String, value: String) {
            self.label = label
            self.value = value
        }
    }

    public let style: Style
    public let title: String
    public let subtitle: String?
    public let fields: [Field]

    public init(
        style: Style,
        title: String,
        subtitle: String?,
        fields: [Field]
    ) {
        self.style = style
        self.title = title
        self.subtitle = subtitle
        self.fields = fields
    }
}

public struct GenericEventTemplate: Sendable, Equatable, Hashable, Codable {
    public let kind: TimelineKind
    public let title: String
    public let location: String?
    public let notes: String?

    public init(
        kind: TimelineKind,
        title: String,
        location: String?,
        notes: String?
    ) {
        self.kind = kind
        self.title = title.trimmingCharacters(in: .whitespacesAndNewlines)
        self.location = location?.nilIfBlank
        self.notes = notes?.nilIfBlank
    }

    public var presentation: EventTemplatePresentation {
        var fields: [EventTemplatePresentation.Field] = [
            .init(label: "类型", value: kindTitle)
        ]
        if let location {
            fields.append(.init(label: "地点", value: location))
        }
        if let notes {
            fields.append(.init(label: "备注", value: notes))
        }
        return EventTemplatePresentation(
            style: .generic,
            title: title,
            subtitle: location ?? notes,
            fields: fields
        )
    }

    private var kindTitle: String {
        switch kind {
        case .meeting: "会议"
        case .task: "任务"
        case .flight: "航班"
        case .train: "火车"
        case .travel: "行程"
        case .interview: "面试"
        case .deadline: "截止"
        case .unknown: "未分类"
        }
    }
}

public struct TrainTicketTemplate: Sendable, Equatable, Hashable, Codable {
    public let trainNumber: String?
    public let departureStation: String?
    public let arrivalStation: String?
    public let departureTimeText: String?
    public let arrivalTimeText: String?
    public let carriageNumber: String?
    public let seatNumber: String?
    public let checkInGate: String?
    public let passengerName: String?
    public let ticketNumber: String?
    public let seatClass: String?
    public let priceText: String?

    public init(
        trainNumber: String?,
        departureStation: String?,
        arrivalStation: String?,
        departureTimeText: String?,
        arrivalTimeText: String?,
        carriageNumber: String?,
        seatNumber: String?,
        checkInGate: String?,
        passengerName: String?,
        ticketNumber: String?,
        seatClass: String? = nil,
        priceText: String? = nil
    ) {
        self.trainNumber = trainNumber?.nilIfBlank
        self.departureStation = departureStation?.nilIfBlank
        self.arrivalStation = arrivalStation?.nilIfBlank
        self.departureTimeText = departureTimeText?.nilIfBlank
        self.arrivalTimeText = arrivalTimeText?.nilIfBlank
        self.carriageNumber = carriageNumber?.nilIfBlank
        self.seatNumber = seatNumber?.nilIfBlank
        self.checkInGate = checkInGate?.nilIfBlank
        self.passengerName = passengerName?.nilIfBlank
        self.ticketNumber = ticketNumber?.nilIfBlank
        self.seatClass = seatClass?.nilIfBlank
        self.priceText = priceText?.nilIfBlank
    }

    public var presentation: EventTemplatePresentation {
        let route = [departureStation, arrivalStation]
            .compactMap(\.?.nilIfBlank)
            .joined(separator: " → ")
        let title = trainNumber ?? "火车票"
        var fields: [EventTemplatePresentation.Field] = []
        append("出发", departureStation, to: &fields)
        append("到达", arrivalStation, to: &fields)
        append("出发时间", departureTimeText, to: &fields)
        append("到达时间", arrivalTimeText, to: &fields)
        append("车厢", carriageNumber.map { "\($0)车" }, to: &fields)
        append("座位", seatNumber, to: &fields)
        append("检票口", checkInGate, to: &fields)
        append("乘车人", passengerName, to: &fields)
        append("票号", ticketNumber, to: &fields)
        append("席别", seatClass, to: &fields)
        append("票价", priceText, to: &fields)

        return EventTemplatePresentation(
            style: .trainTicket,
            title: title,
            subtitle: route.nilIfBlank,
            fields: fields
        )
    }

    private func append(
        _ label: String,
        _ value: String?,
        to fields: inout [EventTemplatePresentation.Field]
    ) {
        guard let value = value?.nilIfBlank else {
            return
        }
        fields.append(.init(label: label, value: value))
    }
}

public struct EventTemplateFactory: Sendable {
    public init() {}

    public func makeTemplate(from input: ClassificationInput) -> TimelineEventTemplate? {
        if let train = makeTrainTicket(from: input) {
            return .trainTicket(train)
        }

        return nil
    }

    public func makeTemplate(from payload: ExternalEventTemplatePayload) -> TimelineEventTemplate? {
        switch payload.kind {
        case .train:
            .trainTicket(.init(
                trainNumber: payload.value(for: "trainNumber", "train_number", "车次"),
                departureStation: payload.value(for: "departureStation", "departure_station", "from", "出发站"),
                arrivalStation: payload.value(for: "arrivalStation", "arrival_station", "to", "到达站", "终点站"),
                departureTimeText: payload.value(for: "departureTime", "departure_time", "出发时间"),
                arrivalTimeText: payload.value(for: "arrivalTime", "arrival_time", "到达时间"),
                carriageNumber: payload.value(for: "carriageNumber", "carriage_number", "coach", "车厢"),
                seatNumber: payload.value(for: "seatNumber", "seat_number", "seat", "座位"),
                checkInGate: payload.value(for: "checkInGate", "check_in_gate", "gate", "检票口"),
                passengerName: payload.value(for: "passengerName", "passenger_name", "乘车人"),
                ticketNumber: payload.value(for: "ticketNumber", "ticket_number", "orderNumber", "票号", "订单号"),
                seatClass: payload.value(for: "seatClass", "seat_class", "class", "席别"),
                priceText: payload.value(for: "price", "priceText", "票价")
            ))
        case .meeting, .task, .flight, .travel, .interview, .deadline, .unknown:
            makeGenericTemplate(from: payload)
        }
    }

    private func makeGenericTemplate(
        from payload: ExternalEventTemplatePayload
    ) -> TimelineEventTemplate? {
        guard let title = payload.value(for: "title", "eventTitle", "事件标题") else {
            return nil
        }
        return .generic(.init(
            kind: payload.kind,
            title: title,
            location: payload.value(for: "location", "地点"),
            notes: payload.value(for: "notes", "description", "details", "备注")
        ))
    }

    private func makeTrainTicket(from input: ClassificationInput) -> TrainTicketTemplate? {
        let text = input.joinedText
        let normalized = input.normalizedText
        let trainNumber = firstMatch(
            in: text,
            pattern: #"(?<![A-Za-z0-9])(?:[GDCZK]\s?\d{1,5}|T\s?\d{2,5})(?![A-Za-z0-9])"#,
            options: [.caseInsensitive]
        )?.replacingOccurrences(of: " ", with: "").uppercased()
        let route = parseRoute(from: text)

        guard trainNumber != nil || route != nil || containsToken(normalized, token: "train") || containsPhrase(text, "高铁", "火车", "动车") else {
            return nil
        }

        return TrainTicketTemplate(
            trainNumber: trainNumber,
            departureStation: route?.departure,
            arrivalStation: route?.arrival,
            departureTimeText: nil,
            arrivalTimeText: nil,
            carriageNumber: firstMatch(in: text, pattern: #"(?<!\d)(\d{1,2})\s?(?:车厢|车)(?!\d)"#),
            seatNumber: firstMatch(in: text, pattern: #"(?<![A-Za-z0-9])\d{1,2}[A-F](?![A-Za-z0-9])"#),
            checkInGate: firstMatch(in: text, pattern: #"检票口\s*([A-Z]?\d{1,3})"#, options: [.caseInsensitive])?.uppercased(),
            passengerName: nil,
            ticketNumber: nil
        )
    }

    private func parseRoute(from text: String) -> (departure: String, arrival: String)? {
        if let match = firstCapturedPair(
            in: text,
            pattern: #"([\p{Han}A-Za-z0-9·]+(?:站|南|北|东|西|虹桥)?)\s*(?:→|->|到|至|-)\s*([\p{Han}A-Za-z0-9·]+(?:站|南|北|东|西|虹桥)?)"#
        ) {
            return match
        }
        return nil
    }

    private func containsPhrase(_ text: String, _ phrases: String...) -> Bool {
        phrases.contains { text.contains($0) }
    }

    private func containsToken(_ text: String, token: String) -> Bool {
        let pattern = "(?<![A-Za-z0-9])\(NSRegularExpression.escapedPattern(for: token))(?![A-Za-z0-9])"
        return text.range(of: pattern, options: .regularExpression) != nil
    }

    private func firstMatch(
        in text: String,
        pattern: String,
        options: NSRegularExpression.Options = []
    ) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: options) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range) else {
            return nil
        }
        let captureIndex = match.numberOfRanges > 1 ? 1 : 0
        guard let matchRange = Range(match.range(at: captureIndex), in: text) else {
            return nil
        }
        return String(text[matchRange]).nilIfBlank
    }

    private func firstCapturedPair(
        in text: String,
        pattern: String
    ) -> (String, String)? {
        guard let regex = try? NSRegularExpression(pattern: pattern) else {
            return nil
        }
        let range = NSRange(text.startIndex..<text.endIndex, in: text)
        guard let match = regex.firstMatch(in: text, range: range),
              match.numberOfRanges >= 3,
              let leftRange = Range(match.range(at: 1), in: text),
              let rightRange = Range(match.range(at: 2), in: text)
        else {
            return nil
        }
        return (String(text[leftRange]), String(text[rightRange]))
    }
}

private extension ExternalEventTemplatePayload {
    func value(for keys: String...) -> String? {
        for key in keys {
            if let exact = fields[key]?.nilIfBlank {
                return exact
            }
            if let match = fields.first(where: { $0.key.caseInsensitiveCompare(key) == .orderedSame })?.value.nilIfBlank {
                return match
            }
        }
        return nil
    }
}

private extension String {
    var nilIfBlank: String? {
        let trimmed = trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed.isEmpty ? nil : trimmed
    }
}
