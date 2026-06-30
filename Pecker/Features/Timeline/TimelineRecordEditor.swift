import Foundation
import PeckerCore
import SwiftUI

enum TimelineRecordEditorError: Error, Equatable {
    case readOnlySource
    case emptyTitle
    case missingStartDate
    case invalidDateRange
}

struct TimelineRecordEditor: Equatable {
    private let original: StoredEventRecord

    var title: String
    var kind: TimelineKind
    var startDate: Date
    var endDate: Date?
    var location: String
    var notes: String

    var trainNumber: String
    var departureStation: String
    var arrivalStation: String
    var carriageNumber: String
    var seatNumber: String
    var checkInGate: String
    var seatClass: String
    var priceText: String
    var ticketNumber: String

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
            carriageNumber = ""
            seatNumber = ""
            checkInGate = ""
            seatClass = ""
            priceText = ""
            ticketNumber = ""
        case let .trainTicket(ticket):
            title = ticket.trainNumber ?? record.rawTitle ?? "\u{706b}\u{8f66}\u{7968}"
            kind = .train
            trainNumber = ticket.trainNumber ?? ""
            departureStation = ticket.departureStation ?? ""
            arrivalStation = ticket.arrivalStation ?? ""
            carriageNumber = ticket.carriageNumber ?? ""
            seatNumber = ticket.seatNumber ?? ""
            checkInGate = ticket.checkInGate ?? ""
            seatClass = ticket.seatClass ?? ""
            priceText = ticket.priceText ?? ""
            ticketNumber = ticket.ticketNumber ?? ""
        case let .flightTicket(ticket):
            title = ticket.flightNumber ?? record.rawTitle ?? "\u{822a}\u{73ed}"
            kind = .flight
            trainNumber = ""
            departureStation = ""
            arrivalStation = ""
            carriageNumber = ""
            seatNumber = ""
            checkInGate = ""
            seatClass = ""
            priceText = ""
            ticketNumber = ""
        case nil:
            title = record.rawTitle ?? ""
            kind = .unknown
            trainNumber = ""
            departureStation = ""
            arrivalStation = ""
            carriageNumber = ""
            seatNumber = ""
            checkInGate = ""
            seatClass = ""
            priceText = ""
            ticketNumber = ""
        }
    }

    var validationError: TimelineRecordEditorError? {
        if title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty {
            return .emptyTitle
        }
        if let endDate, endDate <= startDate {
            return .invalidDateRange
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
                trainNumber: trainNumber.nilIfBlank ?? cleanTitle,
                departureStation: departureStation.nilIfBlank,
                arrivalStation: arrivalStation.nilIfBlank,
                departureTimeText: nil,
                arrivalTimeText: nil,
                carriageNumber: carriageNumber.nilIfBlank,
                seatNumber: seatNumber.nilIfBlank,
                checkInGate: checkInGate.nilIfBlank,
                passengerName: nil,
                ticketNumber: ticketNumber.nilIfBlank,
                seatClass: seatClass.nilIfBlank,
                priceText: priceText.nilIfBlank
            ))
        } else if kind == .flight,
                  case let .flightTicket(ticket) = original.template
        {
            template = .flightTicket(.init(
                flightNumber: cleanTitle,
                carrier: ticket.carrier,
                departureAirport: ticket.departureAirport,
                departureAirportCode: ticket.departureAirportCode,
                arrivalAirport: ticket.arrivalAirport,
                arrivalAirportCode: ticket.arrivalAirportCode,
                departureTimeText: ticket.departureTimeText,
                arrivalTimeText: ticket.arrivalTimeText,
                terminal: ticket.terminal,
                gate: ticket.gate,
                seat: ticket.seat,
                travelStatus: ticket.travelStatus
            ))
        } else {
            let preservedFields: [String: String]
            if case let .generic(event) = original.template {
                preservedFields = event.fields
            } else {
                preservedFields = [:]
            }
            template = .generic(.init(
                kind: kind,
                title: cleanTitle,
                location: cleanLocation,
                notes: cleanNotes,
                fields: preservedFields
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
            template: template,
            recognitionStatus: .recognized,
            updatedAt: updatedAt
        )
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
    let onSave: (TimelineRecordEditor) async throws -> Void

    init(
        editor: TimelineRecordEditor,
        onSave: @escaping (TimelineRecordEditor) async throws -> Void
    ) {
        _editor = State(initialValue: editor)
        _hasEndDate = State(initialValue: editor.endDate != nil)
        self.onSave = onSave
    }

    var body: some View {
        NavigationStack {
            ZStack {
                TimelineTheme.backgroundGradient.ignoresSafeArea()
                Form {
                    Section("\u{4e8b}\u{4ef6}") {
                        TextField("\u{6807}\u{9898}", text: $editor.title)
                        Picker("\u{7c7b}\u{578b}", selection: $editor.kind) {
                            ForEach(TimelineKind.allCases, id: \.self) {
                                Text(kindTitle($0)).tag($0)
                            }
                        }
                        DatePicker("\u{5f00}\u{59cb}", selection: $editor.startDate)
                        Toggle("\u{8bbe}\u{7f6e}\u{7ed3}\u{675f}\u{65f6}\u{95f4}", isOn: $hasEndDate)
                        if hasEndDate {
                            DatePicker(
                                "\u{7ed3}\u{675f}",
                                selection: Binding(
                                    get: {
                                        editor.endDate
                                            ?? editor.startDate.addingTimeInterval(1_800)
                                    },
                                    set: { editor.endDate = $0 }
                                )
                            )
                        }
                        TextField("\u{5730}\u{70b9}", text: $editor.location)
                        TextField("\u{5907}\u{6ce8}", text: $editor.notes, axis: .vertical)
                    }

                    if editor.kind == .train {
                        Section("\u{8f66}\u{7968}") {
                            TextField("\u{8f66}\u{6b21}", text: $editor.trainNumber)
                            TextField("\u{51fa}\u{53d1}\u{7ad9}", text: $editor.departureStation)
                            TextField("\u{5230}\u{8fbe}\u{7ad9}", text: $editor.arrivalStation)
                            TextField("\u{8f66}\u{53a2}", text: $editor.carriageNumber)
                            TextField("\u{5ea7}\u{4f4d}", text: $editor.seatNumber)
                            TextField("\u{68c0}\u{7968}\u{53e3}", text: $editor.checkInGate)
                            TextField("\u{5e2d}\u{522b}", text: $editor.seatClass)
                            TextField("\u{7968}\u{4ef7}", text: $editor.priceText)
                            TextField("\u{7968}\u{53f7} / \u{8ba2}\u{5355}\u{53f7}", text: $editor.ticketNumber)
                        }
                    }

                    if let errorText {
                        Text(errorText)
                            .foregroundStyle(.red)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("\u{7f16}\u{8f91}\u{4e8b}\u{4ef6}")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("\u{53d6}\u{6d88}") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("\u{4fdd}\u{5b58}") {
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
                                errorText = "\u{4fdd}\u{5b58}\u{5931}\u{8d25}，\u{8bf7}\u{68c0}\u{67e5}\u{6807}\u{9898}\u{548c}\u{65f6}\u{95f4}。"
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
        case .meeting: "\u{4f1a}\u{8bae}"
        case .task: "\u{4efb}\u{52a1}"
        case .flight: "\u{822a}\u{73ed}"
        case .train: "\u{706b}\u{8f66}"
        case .travel: "\u{884c}\u{7a0b}"
        case .interview: "\u{9762}\u{8bd5}"
        case .deadline: "\u{622a}\u{6b62}"
        case .unknown: "\u{672a}\u{5206}\u{7c7b}"
        }
    }
}
