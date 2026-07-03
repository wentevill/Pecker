import Foundation
import PeckerCore
import SwiftUI

enum TimelineRecordEditorError: Error, Equatable {
    case readOnlySource
    case emptyTitle
    case missingStartDate
    case invalidDateRange
    case incompleteCustomField(id: String)
    case duplicateCustomField(ids: [String])
}

struct TimelineRecordEditor: Equatable, Identifiable {
    private let original: StoredEventRecord

    var id: String { original.id }

    var title: String
    var kind: TimelineKind
    var startDate: Date
    var endDate: Date?
    var isAllDay: Bool
    var location: String
    var notes: String

    var trainNumber: String
    var departureStation: String
    var arrivalStation: String
    var departureTimeText: String
    var arrivalTimeText: String
    var carriageNumber: String
    var seatNumber: String
    var checkInGate: String
    var passengerName: String
    var seatClass: String
    var priceText: String
    var ticketNumber: String

    var flightNumber: String
    var carrier: String
    var departureAirport: String
    var departureAirportCode: String
    var arrivalAirport: String
    var arrivalAirportCode: String
    var terminal: String
    var gate: String
    var seat: String
    var travelStatus: String

    var customFields: [EventCustomField]

    init(record: StoredEventRecord) throws {
        guard record.source == .importedImage || record.source == .cameraImage else {
            throw TimelineRecordEditorError.readOnlySource
        }
        guard let startDate = record.startDate else {
            throw TimelineRecordEditorError.missingStartDate
        }

        original = record
        self.startDate = startDate
        endDate = record.endDate
        isAllDay = record.isAllDay
        location = record.rawLocation ?? ""
        notes = record.rawNotes ?? ""

        switch record.template {
        case let .generic(event):
            title = event.title
            kind = event.kind
            location = event.location ?? location
            notes = event.notes ?? notes
            trainNumber = ""
            departureStation = ""
            arrivalStation = ""
            departureTimeText = ""
            arrivalTimeText = ""
            carriageNumber = ""
            seatNumber = ""
            checkInGate = ""
            passengerName = ""
            seatClass = ""
            priceText = ""
            ticketNumber = ""
            flightNumber = ""
            carrier = ""
            departureAirport = ""
            departureAirportCode = ""
            arrivalAirport = ""
            arrivalAirportCode = ""
            terminal = ""
            gate = ""
            seat = ""
            travelStatus = ""
            customFields = Self.initialCustomFields(
                record: record,
                legacyFields: event.fields
            )
        case let .trainTicket(ticket):
            title = ticket.trainNumber ?? record.rawTitle ?? "Train ticket"
            kind = .train
            trainNumber = ticket.trainNumber ?? ""
            departureStation = ticket.departureStation ?? ""
            arrivalStation = ticket.arrivalStation ?? ""
            departureTimeText = ticket.departureTimeText ?? ""
            arrivalTimeText = ticket.arrivalTimeText ?? ""
            carriageNumber = ticket.carriageNumber ?? ""
            seatNumber = ticket.seatNumber ?? ""
            checkInGate = ticket.checkInGate ?? ""
            passengerName = ticket.passengerName ?? ""
            seatClass = ticket.seatClass ?? ""
            priceText = ticket.priceText ?? ""
            ticketNumber = ticket.ticketNumber ?? ""
            flightNumber = ""
            carrier = ""
            departureAirport = ""
            departureAirportCode = ""
            arrivalAirport = ""
            arrivalAirportCode = ""
            terminal = ""
            gate = ""
            seat = ""
            travelStatus = ""
            customFields = Self.initialCustomFields(record: record)
        case let .flightTicket(ticket):
            title = ticket.flightNumber ?? record.rawTitle ?? "Flight"
            kind = .flight
            trainNumber = ""
            departureStation = ""
            arrivalStation = ""
            departureTimeText = ticket.departureTimeText ?? ""
            arrivalTimeText = ticket.arrivalTimeText ?? ""
            carriageNumber = ""
            seatNumber = ""
            checkInGate = ""
            passengerName = ""
            seatClass = ""
            priceText = ""
            ticketNumber = ""
            flightNumber = ticket.flightNumber ?? ""
            carrier = ticket.carrier ?? ""
            departureAirport = ticket.departureAirport ?? ""
            departureAirportCode = ticket.departureAirportCode ?? ""
            arrivalAirport = ticket.arrivalAirport ?? ""
            arrivalAirportCode = ticket.arrivalAirportCode ?? ""
            terminal = ticket.terminal ?? ""
            gate = ticket.gate ?? ""
            seat = ticket.seat ?? ""
            travelStatus = ticket.travelStatus ?? ""
            customFields = Self.initialCustomFields(record: record)
        case nil:
            title = record.rawTitle ?? ""
            kind = .unknown
            trainNumber = ""
            departureStation = ""
            arrivalStation = ""
            departureTimeText = ""
            arrivalTimeText = ""
            carriageNumber = ""
            seatNumber = ""
            checkInGate = ""
            passengerName = ""
            seatClass = ""
            priceText = ""
            ticketNumber = ""
            flightNumber = ""
            carrier = ""
            departureAirport = ""
            departureAirportCode = ""
            arrivalAirport = ""
            arrivalAirportCode = ""
            terminal = ""
            gate = ""
            seat = ""
            travelStatus = ""
            customFields = Self.initialCustomFields(record: record)
        }
    }

    var validationError: TimelineRecordEditorError? {
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .emptyTitle
        }
        if let endDate, endDate <= startDate {
            return .invalidDateRange
        }
        for field in customFields {
            let name = field.name.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            let value = field.value.trimmingCharacters(
                in: .whitespacesAndNewlines
            )
            if name.isEmpty != value.isEmpty {
                return .incompleteCustomField(id: field.id)
            }
        }
        var idsByName: [String: [String]] = [:]
        for field in customFields {
            guard let name = field.name.nilIfBlank,
                  field.value.nilIfBlank != nil
            else {
                continue
            }
            let key = name.folding(
                options: [.caseInsensitive, .diacriticInsensitive],
                locale: .current
            )
            idsByName[key, default: []].append(field.id)
        }
        if let duplicateIDs = idsByName.values.first(where: { $0.count > 1 }) {
            return .duplicateCustomField(ids: duplicateIDs)
        }
        return nil
    }

    func makeRecord(updatedAt: Date) throws -> StoredEventRecord {
        if let validationError {
            throw validationError
        }
        let cleanTitle = title.trimmingCharacters(in: .whitespacesAndNewlines)
        let cleanLocation = location.nilIfBlank
        let cleanNotes = notes.nilIfBlank
        let template: TimelineEventTemplate
        if kind == .train {
            template = .trainTicket(.init(
                trainNumber: primaryTicketValue(
                    current: trainNumber,
                    original: originalTrainNumber,
                    cleanTitle: cleanTitle
                ),
                departureStation: departureStation.nilIfBlank,
                arrivalStation: arrivalStation.nilIfBlank,
                departureTimeText: departureTimeText.nilIfBlank,
                arrivalTimeText: arrivalTimeText.nilIfBlank,
                carriageNumber: carriageNumber.nilIfBlank,
                seatNumber: seatNumber.nilIfBlank,
                checkInGate: checkInGate.nilIfBlank,
                passengerName: passengerName.nilIfBlank,
                ticketNumber: ticketNumber.nilIfBlank,
                seatClass: seatClass.nilIfBlank,
                priceText: priceText.nilIfBlank
            ))
        } else if kind == .flight {
            template = .flightTicket(.init(
                flightNumber: primaryTicketValue(
                    current: flightNumber,
                    original: originalFlightNumber,
                    cleanTitle: cleanTitle
                ),
                carrier: carrier.nilIfBlank,
                departureAirport: departureAirport.nilIfBlank,
                departureAirportCode: departureAirportCode.nilIfBlank,
                arrivalAirport: arrivalAirport.nilIfBlank,
                arrivalAirportCode: arrivalAirportCode.nilIfBlank,
                departureTimeText: departureTimeText.nilIfBlank,
                arrivalTimeText: arrivalTimeText.nilIfBlank,
                terminal: terminal.nilIfBlank,
                gate: gate.nilIfBlank,
                seat: seat.nilIfBlank,
                travelStatus: travelStatus.nilIfBlank
            ))
        } else {
            template = .generic(.init(
                kind: kind,
                title: cleanTitle,
                location: cleanLocation,
                notes: cleanNotes,
                fields: [:]
            ))
        }

        return StoredEventRecord(
            id: original.id,
            source: original.source,
            sourceIdentifier: original.sourceIdentifier,
            rawTitle: cleanTitle,
            rawLocation: cleanLocation,
            rawNotes: cleanNotes,
            imageReference: original.imageReference,
            startDate: startDate,
            endDate: endDate,
            isAllDay: isAllDay,
            template: template,
            recognitionStatus: .recognized,
            updatedAt: updatedAt,
            customFields: normalizedCustomFields
        )
    }

    private var normalizedCustomFields: [EventCustomField] {
        customFields.compactMap { field in
            guard let name = field.name.nilIfBlank,
                  let value = field.value.nilIfBlank
            else {
                return nil
            }
            return EventCustomField(id: field.id, name: name, value: value)
        }
    }

    private static func initialCustomFields(
        record: StoredEventRecord,
        legacyFields: [String: String] = [:]
    ) -> [EventCustomField] {
        if !record.customFields.isEmpty {
            return record.customFields
        }
        return legacyFields
            .sorted {
                $0.key.localizedCaseInsensitiveCompare($1.key)
                    == .orderedAscending
            }
            .map { .legacy(name: $0.key, value: $0.value) }
    }

    private var originalFlightNumber: String? {
        guard case let .flightTicket(ticket) = original.template else {
            return nil
        }
        return ticket.flightNumber
    }

    private var originalTrainNumber: String? {
        guard case let .trainTicket(ticket) = original.template else {
            return nil
        }
        return ticket.trainNumber
    }

    private func primaryTicketValue(
        current: String,
        original: String?,
        cleanTitle: String
    ) -> String? {
        let currentValue = current.nilIfBlank
        if currentValue != original?.nilIfBlank {
            return currentValue ?? cleanTitle
        }
        if cleanTitle != originalTitle {
            return cleanTitle
        }
        return currentValue ?? cleanTitle
    }

    private var originalTitle: String {
        original.rawTitle?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
    }
}

private extension String {
    var nilIfBlank: String? {
        let value = trimmingCharacters(in: .whitespacesAndNewlines)
        return value.isEmpty ? nil : value
    }
}

struct TimelineRecordEditorView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var editor: TimelineRecordEditor
    @State private var hasEndDate: Bool
    @State private var isSaving = false
    @State private var errorText: String?
    let localizer: AppLocalizer
    let onSave: (TimelineRecordEditor) async throws -> Void

    init(
        editor: TimelineRecordEditor,
        localizer: AppLocalizer = AppLocalizer(language: .system),
        onSave: @escaping (TimelineRecordEditor) async throws -> Void
    ) {
        _editor = State(initialValue: editor)
        _hasEndDate = State(initialValue: editor.endDate != nil)
        self.localizer = localizer
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ZStack {
                TimelineTheme.backgroundGradient.ignoresSafeArea()
                Form {
                    Section(localizer.string("editor.section.event")) {
                        TextField(localizer.string("editor.title"), text: $editor.title)
                        Picker(localizer.string("editor.kind"), selection: $editor.kind) {
                            ForEach(TimelineKind.allCases, id: \.self) {
                                Text(kindTitle($0)).tag($0)
                            }
                        }
                        Toggle(localizer.string("editor.allDay"), isOn: $editor.isAllDay)
                        DatePicker(localizer.string("editor.start"), selection: $editor.startDate)
                        Toggle(localizer.string("editor.hasEndDate"), isOn: $hasEndDate)
                        if hasEndDate {
                            DatePicker(
                                localizer.string("editor.end"),
                                selection: Binding(
                                    get: {
                                        editor.endDate
                                            ?? editor.startDate.addingTimeInterval(1_800)
                                    },
                                    set: { editor.endDate = $0 }
                                )
                            )
                        }
                        TextField(localizer.string("detail.location"), text: $editor.location)
                        TextField(localizer.string("detail.notes"), text: $editor.notes, axis: .vertical)
                    }

                    if editor.kind == .train {
                        Section(localizer.string("editor.section.ticket")) {
                            TextField(localizer.string("editor.trainNumber"), text: $editor.trainNumber)
                            TextField(localizer.string("train.ticket.departureStation"), text: $editor.departureStation)
                            TextField(localizer.string("train.ticket.arrivalStation"), text: $editor.arrivalStation)
                            TextField(localizer.string("editor.departureTimeText"), text: $editor.departureTimeText)
                            TextField(localizer.string("editor.arrivalTimeText"), text: $editor.arrivalTimeText)
                            TextField(localizer.string("editor.carriage"), text: $editor.carriageNumber)
                            TextField(localizer.string("editor.seat"), text: $editor.seatNumber)
                            TextField(localizer.string("editor.gate"), text: $editor.checkInGate)
                            TextField(localizer.string("editor.passengerName"), text: $editor.passengerName)
                            TextField(localizer.string("editor.seatClass"), text: $editor.seatClass)
                            TextField(localizer.string("editor.price"), text: $editor.priceText)
                            TextField(localizer.string("editor.ticketNumber"), text: $editor.ticketNumber)
                        }
                    }

                    if editor.kind == .flight {
                        Section(localizer.string("editor.section.flight")) {
                            TextField(localizer.string("editor.flightNumber"), text: $editor.flightNumber)
                            TextField(localizer.string("editor.carrier"), text: $editor.carrier)
                            TextField(localizer.string("editor.departureAirport"), text: $editor.departureAirport)
                            TextField(localizer.string("editor.departureAirportCode"), text: $editor.departureAirportCode)
                            TextField(localizer.string("editor.arrivalAirport"), text: $editor.arrivalAirport)
                            TextField(localizer.string("editor.arrivalAirportCode"), text: $editor.arrivalAirportCode)
                            TextField(localizer.string("editor.departureTimeText"), text: $editor.departureTimeText)
                            TextField(localizer.string("editor.arrivalTimeText"), text: $editor.arrivalTimeText)
                            TextField(localizer.string("editor.terminal"), text: $editor.terminal)
                            TextField(localizer.string("editor.gate"), text: $editor.gate)
                            TextField(localizer.string("editor.seat"), text: $editor.seat)
                            TextField(localizer.string("editor.travelStatus"), text: $editor.travelStatus)
                        }
                    }

                    if editor.kind != .train && editor.kind != .flight {
                        Section(localizer.string("editor.section.fields")) {
                            ForEach($editor.customFields) { $field in
                                HStack(spacing: 10) {
                                    TextField(localizer.string("editor.fieldName"), text: $field.name)
                                    TextField(localizer.string("editor.fieldValue"), text: $field.value)
                                }
                            }
                            Button {
                                editor.customFields.append(.init(name: "", value: ""))
                            } label: {
                                Label(localizer.string("editor.addField"), systemImage: "plus")
                            }
                        }
                    }

                    if let errorText {
                        Text(errorText)
                            .foregroundStyle(.red)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(localizer.string("editor.title.navigation"))
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizer.string("common.cancel")) { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button(localizer.string("common.save")) {
                        if !hasEndDate {
                            editor.endDate = nil
                        }
                        Task {
                            isSaving = true
                            defer { isSaving = false }
                            do {
                                try await onSave(editor)
                                dismiss()
                            } catch {
                                errorText = localizer.string("editor.save.error")
                            }
                        }
                    }
                    .disabled(isSaving || editor.validationError != nil)
                }
            }
        }
    }

    private func kindTitle(_ kind: TimelineKind) -> String {
        switch kind {
        case .meeting: localizer.string("timeline.kind.meeting")
        case .task: localizer.string("timeline.kind.task")
        case .flight: localizer.string("timeline.kind.flight")
        case .train: localizer.string("timeline.kind.train")
        case .travel: localizer.string("timeline.kind.travel")
        case .interview: localizer.string("timeline.kind.interview")
        case .deadline: localizer.string("timeline.kind.deadline")
        case .unknown: localizer.string("timeline.kind.unknown")
        }
    }
}
