import Foundation
import PeckerCore

struct LiveActivityPresentationAdapter: Sendable {
    func makeState(
        item: TimelineItem,
        status: PeckerLiveActivityStatus,
        generatedAt: Date,
        language: AppLanguage = .system
    ) -> PeckerActivityAttributes.ContentState {
        let locale = Locale(identifier: language.liveActivityLocaleIdentifier)
        return switch item.template {
        case let .trainTicket(ticket):
            trainState(
                item: item,
                ticket: ticket,
                status: status,
                generatedAt: generatedAt,
                locale: locale
            )
        case let .flightTicket(ticket):
            flightState(
                item: item,
                ticket: ticket,
                status: status,
                generatedAt: generatedAt,
                locale: locale
            )
        case let .generic(event):
            genericState(
                item: item,
                event: event,
                status: status,
                generatedAt: generatedAt,
                locale: locale
            )
        case nil:
            genericState(
                item: item,
                event: nil,
                status: status,
                generatedAt: generatedAt,
                locale: locale
            )
        }
    }

    private func trainState(
        item: TimelineItem,
        ticket: TrainTicketTemplate,
        status: PeckerLiveActivityStatus,
        generatedAt: Date,
        locale: Locale
    ) -> PeckerActivityAttributes.ContentState {
        let route = [ticket.departureStation, ticket.arrivalStation]
            .compactMap(clean)
            .joined(separator: " → ")
        let metadata = [
            ticket.carriageNumber.map {
                localizedValue(label: .car, value: $0, locale: locale)
            },
            ticket.seatNumber.map {
                localizedValue(label: .seat, value: $0, locale: locale)
            },
            ticket.checkInGate.map {
                localizedValue(label: .gate, value: $0, locale: locale)
            },
            ticket.seatClass
        ]
        .compactMap(clean)

        return state(
            item: item,
            status: status,
            title: clean(ticket.trainNumber) ?? item.title,
            secondaryIdentity: clean(route),
            leadingEndpoint: clean(ticket.departureStation),
            trailingEndpoint: clean(ticket.arrivalStation),
            location: clean(item.location),
            supportingDetail: clean(item.notes),
            metadata: metadata,
            localeIdentifier: locale.identifier,
            generatedAt: generatedAt
        )
    }

    private func flightState(
        item: TimelineItem,
        ticket: FlightTicketTemplate,
        status: PeckerLiveActivityStatus,
        generatedAt: Date,
        locale: Locale
    ) -> PeckerActivityAttributes.ContentState {
        let metadata = [
            ticket.terminal,
            ticket.gate.map {
                localizedValue(label: .gate, value: $0, locale: locale)
            },
            ticket.seat.map {
                localizedValue(label: .seat, value: $0, locale: locale)
            },
            ticket.travelStatus
        ]
        .compactMap(clean)

        return state(
            item: item,
            status: status,
            title: clean(ticket.flightNumber) ?? item.title,
            secondaryIdentity: clean(ticket.carrier),
            leadingEndpoint: endpoint(
                name: ticket.departureAirport,
                code: ticket.departureAirportCode
            ),
            trailingEndpoint: endpoint(
                name: ticket.arrivalAirport,
                code: ticket.arrivalAirportCode
            ),
            location: clean(item.location),
            supportingDetail: clean(item.notes),
            metadata: metadata,
            localeIdentifier: locale.identifier,
            generatedAt: generatedAt
        )
    }

    private func genericState(
        item: TimelineItem,
        event: GenericEventTemplate?,
        status: PeckerLiveActivityStatus,
        generatedAt: Date,
        locale: Locale
    ) -> PeckerActivityAttributes.ContentState {
        let location = clean(event?.location) ?? clean(item.location)
        let notes = clean(event?.notes) ?? clean(item.notes)
        let preservedDetail = event?.fields
            .sorted { $0.key < $1.key }
            .lazy
            .filter { !isGenericSupportFieldHidden(key: $0.key, value: $0.value) }
            .map(\.value)
            .compactMap(clean)
            .first

        return state(
            item: item,
            status: status,
            title: clean(event?.title) ?? item.title,
            secondaryIdentity: nil,
            leadingEndpoint: nil,
            trailingEndpoint: nil,
            location: location,
            supportingDetail: notes ?? preservedDetail,
            metadata: [],
            localeIdentifier: locale.identifier,
            generatedAt: generatedAt
        )
    }

    private func state(
        item: TimelineItem,
        status: PeckerLiveActivityStatus,
        title: String,
        secondaryIdentity: String?,
        leadingEndpoint: String?,
        trailingEndpoint: String?,
        location: String?,
        supportingDetail: String?,
        metadata: [String],
        localeIdentifier: String?,
        generatedAt: Date
    ) -> PeckerActivityAttributes.ContentState {
        PeckerActivityAttributes.ContentState(
            itemIdentifier: item.id,
            title: title,
            secondaryIdentity: secondaryIdentity,
            kindRawValue: item.kind.rawValue,
            symbolName: symbolName(for: item.kind),
            statusRawValue: status.rawValue,
            startDate: item.startDate,
            endDate: item.endDate,
            leadingEndpoint: leadingEndpoint,
            trailingEndpoint: trailingEndpoint,
            location: location,
            supportingDetail: supportingDetail,
            metadata: metadata,
            localeIdentifier: localeIdentifier,
            generatedAt: generatedAt
        )
    }

    private func localizedValue(
        label: MetadataLabel,
        value: String,
        locale: Locale
    ) -> String {
        let cleanValue = clean(value) ?? value
        let usesChinese = locale.language.languageCode?.identifier == "zh"
        switch (label, usesChinese) {
        case (.car, true):
            return "\(cleanValue)\u{8f66}"
        case (.seat, true):
            return "\(cleanValue)\u{5ea7}"
        case (.gate, true):
            return "\u{68c0}\u{7968}\u{53e3} \(cleanValue)"
        case (.car, false):
            return "Car \(cleanValue)"
        case (.seat, false):
            return "Seat \(cleanValue)"
        case (.gate, false):
            return "Gate \(cleanValue)"
        }
    }

    private func endpoint(name: String?, code: String?) -> String? {
        switch (clean(code), clean(name)) {
        case let (code?, name?):
            "\(code) · \(name)"
        case let (code?, nil):
            code
        case let (nil, name?):
            name
        case (nil, nil):
            nil
        }
    }

    private func symbolName(for kind: TimelineKind) -> String {
        switch kind {
        case .meeting:
            "person.2.fill"
        case .task:
            "checklist"
        case .flight:
            "airplane"
        case .train:
            "train.side.front.car"
        case .travel:
            "suitcase.fill"
        case .interview:
            "person.text.rectangle"
        case .deadline:
            "calendar.badge.exclamationmark"
        case .unknown:
            "clock.fill"
        }
    }

    private func clean(_ value: String?) -> String? {
        let trimmed = value?.trimmingCharacters(in: .whitespacesAndNewlines)
        return trimmed?.isEmpty == false ? trimmed : nil
    }

    private func isGenericSupportFieldHidden(key: String, value: String) -> Bool {
        if Self.genericIdentityKeys.contains(key) {
            return true
        }

        let normalizedKey = key.lowercased()
        if Self.genericMachineTimeKeys.contains(normalizedKey) {
            return true
        }

        return looksLikeMachineDate(value)
    }

    private func looksLikeMachineDate(_ value: String) -> Bool {
        let trimmed = value.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 16, trimmed.contains("T") else {
            return false
        }

        return trimmed.hasSuffix("Z")
            || trimmed.contains("+")
            || trimmed.dropFirst().contains("-")
    }

    private static let genericIdentityKeys: Set<String> = [
        "title",
        "eventTitle",
        "\u{4e8b}\u{4ef6}\u{6807}\u{9898}",
        "location",
        "\u{5730}\u{70b9}",
        "notes",
        "description",
        "details",
        "\u{5907}\u{6ce8}"
    ]

    private static let genericMachineTimeKeys: Set<String> = [
        "date",
        "datetime",
        "duedate",
        "duedatetime",
        "enddate",
        "enddatetime",
        "endtime",
        "eventdate",
        "startdate",
        "startdatetime",
        "starttime",
        "time"
    ]
}

private enum MetadataLabel {
    case car
    case seat
    case gate
}

private extension AppLanguage {
    var liveActivityLocaleIdentifier: String {
        switch self {
        case .system:
            Locale.preferredLanguages.first ?? "en"
        case .english:
            "en"
        case .simplifiedChinese:
            "zh-Hans"
        }
    }
}

private extension PeckerLiveActivityStatus {
    var rawValue: String {
        switch self {
        case .now:
            "now"
        case .next:
            "next"
        case .pinned:
            "pinned"
        }
    }
}
