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

enum EditorSectionKind: Equatable {
    case common
    case flight
    case train
    case travel
    case custom
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
            departureStation = event.kind == .travel
                ? event.fields["origin"] ?? ""
                : ""
            arrivalStation = event.kind == .travel
                ? event.fields["destination"] ?? ""
                : ""
            departureTimeText = event.kind == .travel
                ? event.fields["departureTime"] ?? ""
                : ""
            arrivalTimeText = event.kind == .travel
                ? event.fields["arrivalTime"] ?? ""
                : ""
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
                legacyFields: event.kind == .travel
                    ? event.fields.filter { !Self.travelFieldKeys.contains($0.key) }
                    : event.fields
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

    static func sections(for kind: TimelineKind) -> [EditorSectionKind] {
        switch kind {
        case .flight:
            [.common, .flight, .custom]
        case .train:
            [.common, .train, .custom]
        case .travel:
            [.common, .travel, .custom]
        case .meeting, .task, .interview, .deadline, .unknown:
            [.common, .custom]
        }
    }

    static func updatedEndDate(
        hasEndDate: Bool,
        current: Date?,
        start: Date
    ) -> Date? {
        guard hasEndDate else {
            return nil
        }
        return current ?? start.addingTimeInterval(1_800)
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
                fields: structuredGenericFields
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
            customFields: customFieldsForSave
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

    private var customFieldsForSave: [EventCustomField] {
        var result = normalizedCustomFields
        let preserved: [(id: String, name: String, value: String)]
        switch original.template {
        case .flightTicket where kind != .flight:
            preserved = [
                ("flightNumber", "Flight number", flightNumber),
                ("carrier", "Carrier", carrier),
                ("departureAirport", "Departure airport", departureAirport),
                ("departureAirportCode", "Departure code", departureAirportCode),
                ("arrivalAirport", "Arrival airport", arrivalAirport),
                ("arrivalAirportCode", "Arrival code", arrivalAirportCode),
                ("departureTime", "Departure time", departureTimeText),
                ("arrivalTime", "Arrival time", arrivalTimeText),
                ("terminal", "Terminal", terminal),
                ("gate", "Gate", gate),
                ("seat", "Seat", seat),
                ("travelStatus", "Status", travelStatus)
            ]
        case .trainTicket where kind != .train:
            preserved = [
                ("trainNumber", "Train number", trainNumber),
                ("departureStation", "Departure station", departureStation),
                ("arrivalStation", "Arrival station", arrivalStation),
                ("departureTime", "Departure time", departureTimeText),
                ("arrivalTime", "Arrival time", arrivalTimeText),
                ("carriage", "Carriage", carriageNumber),
                ("seat", "Seat", seatNumber),
                ("checkInGate", "Gate", checkInGate),
                ("passenger", "Passenger", passengerName),
                ("seatClass", "Seat class", seatClass),
                ("price", "Price", priceText),
                ("ticketNumber", "Ticket number", ticketNumber)
            ]
        case .generic, .flightTicket, .trainTicket, nil:
            preserved = []
        }

        for field in preserved {
            guard let value = field.value.nilIfBlank else {
                continue
            }
            let duplicate = result.contains {
                $0.name.compare(
                    field.name,
                    options: [.caseInsensitive, .diacriticInsensitive]
                ) == .orderedSame
            }
            if !duplicate {
                result.append(.init(
                    id: "preserved:\(field.id)",
                    name: field.name,
                    value: value
                ))
            }
        }
        return result
    }

    private var structuredGenericFields: [String: String] {
        guard kind == .travel else {
            return [:]
        }
        return [
            "origin": departureStation,
            "destination": arrivalStation,
            "departureTime": departureTimeText,
            "arrivalTime": arrivalTimeText
        ].compactMapValues(\.nilIfBlank)
    }

    private static let travelFieldKeys: Set<String> = [
        "origin",
        "destination",
        "departureTime",
        "arrivalTime"
    ]

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
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @State private var editor: TimelineRecordEditor
    @State private var hasEndDate: Bool
    @State private var isSaving = false
    @State private var errorText: String?
    @State private var showsDiscardConfirmation = false
    @FocusState private var focusedField: FocusedField?
    private let initialEditor: TimelineRecordEditor
    let localizer: AppLocalizer
    let onSave: (TimelineRecordEditor) async throws -> Void

    private enum FocusedField: Hashable {
        case title
        case location
        case notes
        case customName(String)
        case customValue(String)
    }

    init(
        editor: TimelineRecordEditor,
        localizer: AppLocalizer = AppLocalizer(language: .system),
        onSave: @escaping (TimelineRecordEditor) async throws -> Void
    ) {
        _editor = State(initialValue: editor)
        _hasEndDate = State(initialValue: editor.endDate != nil)
        initialEditor = editor
        self.localizer = localizer
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 20) {
                    hero
                    kindPicker
                    commonSection
                    typeSpecificSection
                        .id(editor.kind)
                        .transition(
                            reduceMotion
                                ? .identity
                                : .opacity.combined(with: .move(edge: .top))
                        )
                    customFieldsSection
                    if let validationMessage {
                        errorBanner(validationMessage)
                    }
                    if let errorText {
                        errorBanner(errorText)
                    }
                }
                .padding(.horizontal, 16)
                .padding(.top, 10)
                .padding(.bottom, 110)
            }
            .scrollDismissesKeyboard(.interactively)
            .background(Color(uiColor: .systemGroupedBackground))
            .navigationTitle(localizer.string("editor.title.navigation"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button(localizer.string("common.cancel")) {
                        cancel()
                    }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button {
                        save()
                    } label: {
                        if isSaving {
                            ProgressView()
                                .controlSize(.small)
                                .accessibilityLabel(
                                    localizer.string("editor.save.progress")
                                )
                        } else {
                            Text(localizer.string("common.save"))
                        }
                    }
                    .disabled(isSaving || editor.validationError != nil)
                }
            }
            .safeAreaInset(edge: .bottom) {
                if focusedField == nil {
                    Button {
                        save()
                    } label: {
                        Text(localizer.string("common.save"))
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .frame(height: 50)
                    }
                    .buttonStyle(.borderedProminent)
                    .buttonBorderShape(.roundedRectangle(radius: 15))
                    .tint(kindColor(editor.kind))
                    .disabled(isSaving || editor.validationError != nil)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)
                    .background(.bar)
                }
            }
            .confirmationDialog(
                localizer.string("editor.discard.title"),
                isPresented: $showsDiscardConfirmation,
                titleVisibility: .visible
            ) {
                Button(
                    localizer.string("editor.discard.action"),
                    role: .destructive
                ) {
                    dismiss()
                }
                Button(
                    localizer.string("editor.continueEditing"),
                    role: .cancel
                ) {}
            } message: {
                Text(localizer.string("editor.discard.message"))
            }
        }
        .interactiveDismissDisabled(editor != initialEditor)
        .onChange(of: hasEndDate) { _, enabled in
            editor.endDate = TimelineRecordEditor.updatedEndDate(
                hasEndDate: enabled,
                current: editor.endDate,
                start: editor.startDate
            )
        }
    }

    private var hero: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: kindSymbol(editor.kind))
                .font(.system(size: 20, weight: .semibold))
                .foregroundStyle(.white)
                .frame(width: 44, height: 44)
                .background(kindColor(editor.kind), in: RoundedRectangle(
                    cornerRadius: 13,
                    style: .continuous
                ))

            VStack(alignment: .leading, spacing: 5) {
                TextField(
                    localizer.string("editor.title"),
                    text: $editor.title,
                    axis: .vertical
                )
                .font(.title2.weight(.bold))
                .textInputAutocapitalization(.sentences)
                .focused($focusedField, equals: .title)

                Text(editorSummary)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
            }
        }
        .padding(.top, 2)
    }

    private var kindPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(TimelineKind.allCases, id: \.self) { kind in
                    Button {
                        withAnimation(
                            reduceMotion
                                ? nil
                                : .snappy(duration: 0.24)
                        ) {
                            editor.kind = kind
                        }
                    } label: {
                        Label(kindTitle(kind), systemImage: kindSymbol(kind))
                            .font(.subheadline.weight(.semibold))
                            .padding(.horizontal, 12)
                            .frame(height: 36)
                            .foregroundStyle(
                                editor.kind == kind ? .white : .primary
                            )
                            .background(
                                editor.kind == kind
                                    ? kindColor(kind)
                                    : Color(uiColor: .secondarySystemGroupedBackground),
                                in: Capsule()
                            )
                    }
                    .buttonStyle(.plain)
                    .accessibilityAddTraits(
                        editor.kind == kind ? .isSelected : []
                    )
                }
            }
        }
    }

    private var commonSection: some View {
        EditorSectionCard(
            title: localizer.string("editor.section.common"),
            systemImage: "calendar"
        ) {
            Toggle(
                localizer.string("editor.allDay"),
                isOn: $editor.isAllDay
            )
            EditorDivider()
            DatePicker(
                localizer.string("editor.start"),
                selection: $editor.startDate
            )
            EditorDivider()
            Toggle(
                localizer.string("editor.hasEndDate"),
                isOn: $hasEndDate
            )
            if hasEndDate {
                EditorDivider()
                DatePicker(
                    localizer.string("editor.end"),
                    selection: endDateBinding
                )
            }
            EditorDivider()
            EditorTextRow(
                title: localizer.string("detail.location"),
                text: $editor.location,
                prompt: localizer.string("editor.location.prompt")
            )
            .focused($focusedField, equals: .location)
            EditorDivider()
            VStack(alignment: .leading, spacing: 8) {
                Text(localizer.string("detail.notes"))
                    .font(.caption)
                    .foregroundStyle(.secondary)
                TextField(
                    localizer.string("editor.notes.prompt"),
                    text: $editor.notes,
                    axis: .vertical
                )
                .lineLimit(2...6)
                .focused($focusedField, equals: .notes)
            }
            .padding(.vertical, 11)
        }
    }

    @ViewBuilder
    private var typeSpecificSection: some View {
        switch editor.kind {
        case .flight:
            flightSection
        case .train:
            trainSection
        case .travel:
            travelSection
        case .meeting, .task, .interview, .deadline, .unknown:
            EmptyView()
        }
    }

    private var flightSection: some View {
        EditorSectionCard(
            title: localizer.string("editor.section.flight"),
            systemImage: "airplane"
        ) {
            editorTextRows([
                (localizer.string("editor.flightNumber"), $editor.flightNumber),
                (localizer.string("editor.carrier"), $editor.carrier),
                (localizer.string("editor.departureAirport"), $editor.departureAirport),
                (localizer.string("editor.departureAirportCode"), $editor.departureAirportCode),
                (localizer.string("editor.arrivalAirport"), $editor.arrivalAirport),
                (localizer.string("editor.arrivalAirportCode"), $editor.arrivalAirportCode),
                (localizer.string("editor.departureTimeText"), $editor.departureTimeText),
                (localizer.string("editor.arrivalTimeText"), $editor.arrivalTimeText),
                (localizer.string("editor.terminal"), $editor.terminal),
                (localizer.string("editor.gate"), $editor.gate),
                (localizer.string("editor.seat"), $editor.seat),
                (localizer.string("editor.travelStatus"), $editor.travelStatus)
            ])
        }
    }

    private var trainSection: some View {
        EditorSectionCard(
            title: localizer.string("editor.section.ticket"),
            systemImage: "tram.fill"
        ) {
            editorTextRows([
                (localizer.string("editor.trainNumber"), $editor.trainNumber),
                (localizer.string("train.ticket.departureStation"), $editor.departureStation),
                (localizer.string("train.ticket.arrivalStation"), $editor.arrivalStation),
                (localizer.string("editor.departureTimeText"), $editor.departureTimeText),
                (localizer.string("editor.arrivalTimeText"), $editor.arrivalTimeText),
                (localizer.string("editor.carriage"), $editor.carriageNumber),
                (localizer.string("editor.seat"), $editor.seatNumber),
                (localizer.string("editor.gate"), $editor.checkInGate),
                (localizer.string("editor.passengerName"), $editor.passengerName),
                (localizer.string("editor.seatClass"), $editor.seatClass),
                (localizer.string("editor.price"), $editor.priceText),
                (localizer.string("editor.ticketNumber"), $editor.ticketNumber)
            ])
        }
    }

    private var travelSection: some View {
        EditorSectionCard(
            title: localizer.string("editor.section.travel"),
            systemImage: "suitcase.rolling.fill"
        ) {
            editorTextRows([
                (localizer.string("editor.travel.origin"), $editor.departureStation),
                (localizer.string("editor.travel.destination"), $editor.arrivalStation),
                (localizer.string("editor.departureTimeText"), $editor.departureTimeText),
                (localizer.string("editor.arrivalTimeText"), $editor.arrivalTimeText)
            ])
        }
    }

    private var customFieldsSection: some View {
        EditorSectionCard(
            title: localizer.string("editor.section.custom"),
            systemImage: "list.bullet.rectangle.portrait"
        ) {
            if editor.customFields.isEmpty {
                Text(localizer.string("editor.customField.empty"))
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .padding(.vertical, 11)
            } else {
                ForEach($editor.customFields) { $field in
                    customFieldRow($field)
                    if field.id != editor.customFields.last?.id {
                        EditorDivider()
                    }
                }
            }

            if !editor.customFields.isEmpty {
                EditorDivider()
            }

            Button {
                addCustomField()
            } label: {
                Label(
                    localizer.string("editor.addField"),
                    systemImage: "plus.circle.fill"
                )
                .font(.subheadline.weight(.semibold))
                .frame(maxWidth: .infinity, alignment: .leading)
                .frame(height: 44)
            }
            .buttonStyle(.plain)
            .foregroundStyle(kindColor(editor.kind))
        }
    }

    private func customFieldRow(
        _ field: Binding<EventCustomField>
    ) -> some View {
        HStack(alignment: .center, spacing: 10) {
            VStack(spacing: 8) {
                TextField(
                    localizer.string("editor.fieldName"),
                    text: field.name
                )
                .font(.subheadline.weight(.semibold))
                .focused(
                    $focusedField,
                    equals: .customName(field.wrappedValue.id)
                )
                .submitLabel(.next)
                .onSubmit {
                    focusedField = .customValue(field.wrappedValue.id)
                }

                TextField(
                    localizer.string("editor.fieldValue"),
                    text: field.value
                )
                .font(.body)
                .focused(
                    $focusedField,
                    equals: .customValue(field.wrappedValue.id)
                )
                .submitLabel(.done)
            }
            .padding(.vertical, 10)

            Button(role: .destructive) {
                deleteCustomField(id: field.wrappedValue.id)
            } label: {
                Image(systemName: "minus.circle.fill")
                    .font(.title3)
                    .symbolRenderingMode(.hierarchical)
            }
            .buttonStyle(.plain)
            .accessibilityLabel(
                localizer.string("editor.customField.delete.accessibility")
            )

            Image(systemName: "line.3.horizontal")
                .font(.body.weight(.semibold))
                .foregroundStyle(.tertiary)
                .frame(width: 30, height: 44)
                .contentShape(Rectangle())
                .draggable(field.wrappedValue.id)
                .accessibilityLabel(
                    localizer.string("editor.customField.reorder.accessibility")
                )
        }
        .dropDestination(for: String.self) { ids, _ in
            guard let draggedID = ids.first else {
                return false
            }
            return moveCustomField(
                id: draggedID,
                before: field.wrappedValue.id
            )
        }
    }

    @ViewBuilder
    private func editorTextRows(
        _ rows: [(String, Binding<String>)]
    ) -> some View {
        ForEach(Array(rows.enumerated()), id: \.offset) { index, row in
            EditorTextRow(
                title: row.0,
                text: row.1,
                prompt: localizer.string("editor.optional.prompt")
            )
            if index < rows.count - 1 {
                EditorDivider()
            }
        }
    }

    private var endDateBinding: Binding<Date> {
        Binding(
            get: {
                editor.endDate
                    ?? editor.startDate.addingTimeInterval(1_800)
            },
            set: { editor.endDate = $0 }
        )
    }

    private var editorSummary: String {
        let style = Date.FormatStyle(date: .abbreviated, time: .shortened)
            .locale(localizer.locale)
        if let endDate = editor.endDate, hasEndDate {
            return "\(editor.startDate.formatted(style)) – \(endDate.formatted(style))"
        }
        return editor.startDate.formatted(style)
    }

    private var validationMessage: String? {
        switch editor.validationError {
        case .emptyTitle:
            localizer.string("editor.validation.title")
        case .invalidDateRange:
            localizer.string("editor.validation.dateRange")
        case .incompleteCustomField:
            localizer.string("editor.customField.incomplete")
        case .duplicateCustomField:
            localizer.string("editor.customField.duplicate")
        case .readOnlySource, .missingStartDate, nil:
            nil
        }
    }

    private func errorBanner(_ text: String) -> some View {
        Label(text, systemImage: "exclamationmark.circle.fill")
            .font(.subheadline)
            .foregroundStyle(.red)
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color.red.opacity(0.1), in: RoundedRectangle(
                cornerRadius: 14,
                style: .continuous
            ))
    }

    private func addCustomField() {
        let field = EventCustomField(name: "", value: "")
        editor.customFields.append(field)
        focusedField = .customName(field.id)
    }

    private func deleteCustomField(id: String) {
        editor.customFields.removeAll { $0.id == id }
        if focusedField == .customName(id)
            || focusedField == .customValue(id)
        {
            focusedField = nil
        }
    }

    private func moveCustomField(id: String, before targetID: String) -> Bool {
        guard id != targetID,
              let source = editor.customFields.firstIndex(
                where: { $0.id == id }
              ),
              let target = editor.customFields.firstIndex(
                where: { $0.id == targetID }
              )
        else {
            return false
        }
        let field = editor.customFields.remove(at: source)
        let insertion = source < target ? target - 1 : target
        editor.customFields.insert(field, at: insertion)
        return true
    }

    private func cancel() {
        if editor == initialEditor {
            dismiss()
        } else {
            showsDiscardConfirmation = true
        }
    }

    private func save() {
        guard !isSaving, editor.validationError == nil else {
            return
        }
        if !hasEndDate {
            editor.endDate = nil
        }
        focusedField = nil
        errorText = nil
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

    private func kindSymbol(_ kind: TimelineKind) -> String {
        switch kind {
        case .meeting: "person.2.fill"
        case .task: "checkmark.circle.fill"
        case .flight: "airplane"
        case .train: "tram.fill"
        case .travel: "suitcase.rolling.fill"
        case .interview: "person.crop.rectangle.stack.fill"
        case .deadline: "flag.checkered"
        case .unknown: "sparkles"
        }
    }

    private func kindColor(_ kind: TimelineKind) -> Color {
        switch kind {
        case .meeting: .blue
        case .task: .green
        case .flight: .indigo
        case .train: .orange
        case .travel: .teal
        case .interview: .purple
        case .deadline: .red
        case .unknown: .gray
        }
    }
}

private struct EditorSectionCard<Content: View>: View {
    let title: String
    let systemImage: String
    @ViewBuilder let content: Content

    init(
        title: String,
        systemImage: String,
        @ViewBuilder content: () -> Content
    ) {
        self.title = title
        self.systemImage = systemImage
        self.content = content()
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Label(title, systemImage: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .textCase(.uppercase)
                .padding(.horizontal, 2)
                .padding(.bottom, 8)

            VStack(alignment: .leading, spacing: 0) {
                content
            }
            .padding(.horizontal, 14)
            .background(
                Color(uiColor: .secondarySystemGroupedBackground),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .overlay {
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(Color.primary.opacity(0.06), lineWidth: 0.5)
            }
        }
    }
}

private struct EditorTextRow: View {
    let title: String
    @Binding var text: String
    let prompt: String

    var body: some View {
        HStack(alignment: .firstTextBaseline, spacing: 12) {
            Text(title)
                .font(.subheadline)
                .foregroundStyle(.secondary)
                .frame(width: 112, alignment: .leading)

            TextField(prompt, text: $text)
                .font(.body)
                .multilineTextAlignment(.trailing)
        }
        .frame(minHeight: 46)
    }
}

private struct EditorDivider: View {
    var body: some View {
        Divider()
            .padding(.leading, 2)
    }
}
