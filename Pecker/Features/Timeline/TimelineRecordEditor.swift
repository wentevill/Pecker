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
            title = ticket.trainNumber ?? record.rawTitle ?? "火车票"
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
            title = ticket.flightNumber ?? record.rawTitle ?? "航班"
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
            template = .generic(.init(
                kind: kind,
                title: cleanTitle,
                location: cleanLocation,
                notes: cleanNotes
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
                    Section("事件") {
                        TextField("标题", text: $editor.title)
                        Picker("类型", selection: $editor.kind) {
                            ForEach(TimelineKind.allCases, id: \.self) {
                                Text(kindTitle($0)).tag($0)
                            }
                        }
                        DatePicker("开始", selection: $editor.startDate)
                        Toggle("设置结束时间", isOn: $hasEndDate)
                        if hasEndDate {
                            DatePicker(
                                "结束",
                                selection: Binding(
                                    get: {
                                        editor.endDate
                                            ?? editor.startDate.addingTimeInterval(1_800)
                                    },
                                    set: { editor.endDate = $0 }
                                )
                            )
                        }
                        TextField("地点", text: $editor.location)
                        TextField("备注", text: $editor.notes, axis: .vertical)
                    }

                    if editor.kind == .train {
                        Section("车票") {
                            TextField("车次", text: $editor.trainNumber)
                            TextField("出发站", text: $editor.departureStation)
                            TextField("到达站", text: $editor.arrivalStation)
                            TextField("车厢", text: $editor.carriageNumber)
                            TextField("座位", text: $editor.seatNumber)
                            TextField("检票口", text: $editor.checkInGate)
                            TextField("席别", text: $editor.seatClass)
                            TextField("票价", text: $editor.priceText)
                            TextField("票号 / 订单号", text: $editor.ticketNumber)
                        }
                    }

                    if let errorText {
                        Text(errorText)
                            .foregroundStyle(.red)
                    }
                }
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("编辑事件")
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("取消") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("保存") {
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
                                errorText = "保存失败，请检查标题和时间。"
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
