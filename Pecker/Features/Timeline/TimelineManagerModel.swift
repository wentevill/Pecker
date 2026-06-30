import Foundation
import Observation
import PeckerCore

@MainActor
@Observable
final class TimelineManagerModel {
    private let gateway: any EventKitGatewayProtocol
    private let mapper: EventKitMapper
    private let recognizer: any SystemEventRecognizing
    private let localCards: any LocalTimelineCardManaging
    private let settingsStore: SettingsStore
    private let calendar: Calendar
    private let classifier = TimelineClassifier()
    @ObservationIgnored
    var onMutation: @MainActor () async -> Void = {}

    var selectedScope: TimelineDateScope = .today
    var selectedKind: TimelineKind?
    private(set) var items: [TimelineItem] = []
    private(set) var recordsByID: [String: StoredEventRecord] = [:]
    private(set) var isLoading = false
    private(set) var errorText: String?
    private(set) var referenceDate = Date.now

    init(
        gateway: any EventKitGatewayProtocol,
        mapper: EventKitMapper,
        recognizer: any SystemEventRecognizing,
        localCards: any LocalTimelineCardManaging,
        settingsStore: SettingsStore,
        calendar: Calendar
    ) {
        self.gateway = gateway
        self.mapper = mapper
        self.recognizer = recognizer
        self.localCards = localCards
        self.settingsStore = settingsStore
        self.calendar = calendar
    }

    var visibleItems: [TimelineItem] {
        Self.visibleItems(
            from: items,
            scope: selectedScope,
            kind: selectedKind,
            calendar: calendar,
            now: referenceDate
        )
    }

    func load(now: Date = .now) async {
        referenceDate = now
        isLoading = true
        errorText = nil
        defer { isLoading = false }

        do {
            let settings = settingsStore.value
            let authorization = await gateway.authorization()
            let interval = loadInterval(now: now)
            async let events = settings.calendarEnabled
                && authorization.calendar == .fullAccess
                ? gateway.fetchEvents(in: interval, calendar: calendar)
                : []
            async let reminders = settings.remindersEnabled
                && authorization.reminders == .fullAccess
                ? gateway.fetchReminders(in: interval, calendar: calendar)
                : []
            async let localItems = recognizer.recognizedImageItems(
                settings: settings,
                now: now
            )
            async let localRecords = localCards.loadAll()

            let (eventRecords, reminderRecords, externalItems, records) = try await (
                events,
                reminders,
                localItems,
                localRecords
            )
            recordsByID = Dictionary(
                uniqueKeysWithValues: records.map { ($0.id, $0) }
            )
            var merged = eventRecords.map { normalize(mapper.mapEvent($0)) }
            merged += reminderRecords.compactMap {
                mapper.mapReminder($0).map(normalize)
            }
            merged += externalItems
            items = Dictionary(
                merged.map { ($0.id, $0) },
                uniquingKeysWith: { _, latest in latest }
            ).values.map { $0 }
        } catch is CancellationError {
            return
        } catch {
            errorText = "\u{65f6}\u{95f4}\u{7ebf}\u{52a0}\u{8f7d}\u{5931}\u{8d25}，\u{8bf7}\u{91cd}\u{8bd5}。"
        }
    }

    func setScope(_ scope: TimelineDateScope, now: Date = .now) async {
        selectedScope = scope
        await load(now: now)
    }

    func isEditable(_ item: TimelineItem) -> Bool {
        item.source == .external
    }

    func editor(for item: TimelineItem) throws -> TimelineRecordEditor {
        guard let record = recordsByID[item.id] else {
            throw LocalTimelineCardError.recordNotFound
        }
        return try TimelineRecordEditor(record: record)
    }

    func save(
        _ editor: TimelineRecordEditor,
        now: Date = .now
    ) async throws {
        try await localCards.update(editor.makeRecord(updatedAt: now))
        await load(now: now)
        await onMutation()
    }

    func delete(_ item: TimelineItem, now: Date = .now) async throws {
        guard isEditable(item) else {
            throw LocalTimelineCardError.readOnlySource
        }
        try await localCards.delete(id: item.id)
        if settingsStore.value.manualPinnedSourceIdentifier
            == item.sourceIdentifier
        {
            settingsStore.update {
                $0.manualPinnedSourceIdentifier = nil
            }
        }
        await load(now: now)
        await onMutation()
    }

    nonisolated static func visibleItems(
        from items: [TimelineItem],
        scope: TimelineDateScope,
        kind: TimelineKind?,
        calendar: Calendar,
        now: Date
    ) -> [TimelineItem] {
        let filtered = items.filter { item in
            TimelineDateScope.classify(item, calendar: calendar, now: now)
                == scope
                && (kind == nil || item.kind == kind)
        }
        if scope == .history {
            return filtered.sorted { $0.startDate > $1.startDate }
        }
        return filtered.sorted {
            if $0.startDate != $1.startDate {
                return $0.startDate < $1.startDate
            }
            return $0.id < $1.id
        }
    }

    private func loadInterval(now: Date) -> DateInterval {
        let startToday = calendar.startOfDay(for: now)
        let tomorrow = calendar.date(
            byAdding: .day,
            value: 1,
            to: startToday
        ) ?? startToday.addingTimeInterval(86_400)
        switch selectedScope {
        case .today:
            return DateInterval(start: startToday, end: tomorrow)
        case .future:
            let end = calendar.date(byAdding: .year, value: 1, to: tomorrow)
                ?? tomorrow.addingTimeInterval(366 * 86_400)
            return DateInterval(start: tomorrow, end: end)
        case .history:
            let start = calendar.date(byAdding: .year, value: -1, to: startToday)
                ?? startToday.addingTimeInterval(-366 * 86_400)
            return DateInterval(start: start, end: startToday)
        }
    }

    private func normalize(_ item: TimelineItem) -> TimelineItem {
        let kind = classifier.classify(
            title: item.title,
            location: item.location,
            notes: item.notes,
            source: item.source
        )
        return TimelineItem(
            id: item.id,
            sourceIdentifier: item.sourceIdentifier,
            title: item.title,
            startDate: item.startDate,
            endDate: item.endDate,
            isAllDay: item.isAllDay,
            source: item.source,
            kind: kind,
            location: item.location,
            notes: item.notes,
            template: item.template,
            isCompleted: item.isCompleted
        )
    }
}
