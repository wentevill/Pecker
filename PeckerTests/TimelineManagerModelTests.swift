import Foundation
import PeckerCore
import XCTest
@testable import Pecker

final class TimelineManagerModelTests: XCTestCase {
    @MainActor
    func testLoadUsesCachedSystemTemplateBeforeLocalClassification() async throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let template = TimelineEventTemplate.trainTicket(.init(
            trainNumber: "G123",
            departureStation: "Shanghai",
            arrivalStation: "Beijing",
            departureTimeText: nil,
            arrivalTimeText: nil,
            carriageNumber: nil,
            seatNumber: nil,
            checkInGate: nil,
            passengerName: nil,
            ticketNumber: nil
        ))
        let suiteName = "TimelineTemplateTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        addTeardownBlock {
            UserDefaults(suiteName: suiteName)?
                .removePersistentDomain(forName: suiteName)
        }
        let model = TimelineManagerModel(
            gateway: TimelineManagerTestGateway(events: [
                EventRecord(
                    identifier: "event-1",
                    title: "Ordinary title",
                    startDate: now,
                    endDate: now.addingTimeInterval(3_600),
                    isAllDay: false,
                    location: nil,
                    notes: nil
                )
            ]),
            mapper: EventKitMapper(),
            recognizer: TimelineManagerTestRecognizer(
                items: [],
                templates: ["calendar:event-1": template]
            ),
            localCards: TimelineManagerTestLocalCards(
                records: [],
                loadError: nil
            ),
            settingsStore: SettingsStore(defaults: defaults),
            calendar: Calendar(identifier: .gregorian)
        )

        let didLoad = await model.load(now: now)
        XCTAssertTrue(didLoad)

        let item = try XCTUnwrap(model.items.first)
        XCTAssertEqual(item.kind, .train)
        XCTAssertEqual(item.template, template)
    }

    func testScopeAndKindFiltersComposeWithoutDateLeakage() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let todayTrain = item(
            id: "today-train",
            start: now,
            kind: .train
        )
        let todayMeeting = item(
            id: "today-meeting",
            start: now.addingTimeInterval(60),
            kind: .meeting
        )
        let tomorrow = calendar.date(
            byAdding: .day,
            value: 1,
            to: calendar.startOfDay(for: now)
        )!
        let futureTrain = item(
            id: "future-train",
            start: tomorrow,
            kind: .train
        )

        let visible = TimelineManagerModel.visibleItems(
            from: [futureTrain, todayMeeting, todayTrain],
            scope: .today,
            kind: .train,
            calendar: calendar,
            now: now
        )

        XCTAssertEqual(visible.map(\.id), ["today-train"])
    }

    func testHistoryUsesReverseChronologicalOrder() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let older = item(
            id: "older",
            start: calendar.date(byAdding: .day, value: -2, to: now)!,
            kind: .task
        )
        let newer = item(
            id: "newer",
            start: calendar.date(byAdding: .day, value: -1, to: now)!,
            kind: .task
        )

        let visible = TimelineManagerModel.visibleItems(
            from: [older, newer],
            scope: .history,
            kind: nil,
            calendar: calendar,
            now: now
        )

        XCTAssertEqual(visible.map(\.id), ["newer", "older"])
    }

    @MainActor
    func testRevealSavedRecordReloadsClearsKindFilterAndSelectsRecordScope() async {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        let record = storedRecord(
            id: "image:warehouse-patrol",
            start: now.addingTimeInterval(-60),
            end: nil
        )
        let recognizedItem = try! XCTUnwrap(
            TimelineManagerModel.timelineItem(from: record, now: now)
        )
        let model = makeModel(
            recognizedItems: [recognizedItem],
            records: [record],
            calendar: calendar
        )
        model.selectedScope = .future
        model.selectedKind = .train

        let didReveal = await model.revealSavedRecord(record, now: now)

        XCTAssertTrue(didReveal)
        XCTAssertNil(model.selectedKind)
        XCTAssertEqual(model.selectedScope, .today)
        XCTAssertEqual(model.visibleItems.map(\.id), [record.id])
    }

    @MainActor
    func testRevealSavedRecordFailsWhenReloadCannotReadRecords() async {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let record = storedRecord(
            id: "image:warehouse-patrol",
            start: now,
            end: nil
        )
        let recognizedItem = try! XCTUnwrap(
            TimelineManagerModel.timelineItem(from: record, now: now)
        )
        let model = makeModel(
            recognizedItems: [recognizedItem],
            records: [record],
            localCardsError: TimelineManagerTestError.load
        )

        let didReveal = await model.revealSavedRecord(record, now: now)

        XCTAssertFalse(didReveal)
        XCTAssertNotNil(model.errorText)
    }

    func testTimelineItemCarriesRecordCustomFields() throws {
        let fields = [
            EventCustomField(id: "booking", name: "Booking", value: "K8X2")
        ]
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let record = storedRecord(
            id: "image:custom-fields",
            start: now,
            end: nil,
            customFields: fields
        )

        let item = try XCTUnwrap(
            TimelineManagerModel.timelineItem(from: record, now: now)
        )

        XCTAssertEqual(item.customFields, fields)
    }

    @MainActor
    private func makeModel(
        recognizedItems: [TimelineItem],
        records: [StoredEventRecord],
        localCardsError: Error? = nil,
        calendar: Calendar = Calendar(identifier: .gregorian)
    ) -> TimelineManagerModel {
        let suiteName = "TimelineManagerModelTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        addTeardownBlock {
            UserDefaults(suiteName: suiteName)?
                .removePersistentDomain(forName: suiteName)
        }
        let settingsStore = SettingsStore(defaults: defaults)
        settingsStore.update {
            $0.calendarEnabled = false
            $0.remindersEnabled = false
        }
        return TimelineManagerModel(
            gateway: TimelineManagerTestGateway(),
            mapper: EventKitMapper(),
            recognizer: TimelineManagerTestRecognizer(items: recognizedItems),
            localCards: TimelineManagerTestLocalCards(
                records: records,
                loadError: localCardsError
            ),
            settingsStore: settingsStore,
            calendar: calendar
        )
    }

    private func storedRecord(
        id: String,
        start: Date,
        end: Date?,
        customFields: [EventCustomField] = []
    ) -> StoredEventRecord {
        StoredEventRecord(
            id: id,
            source: .importedImage,
            sourceIdentifier: id,
            rawTitle: "Warehouse patrol",
            rawLocation: "Warehouse",
            rawNotes: nil,
            imageReference: "Images/warehouse.jpg",
            startDate: start,
            endDate: end,
            template: .generic(.init(
                kind: .task,
                title: "Warehouse patrol",
                location: "Warehouse",
                notes: nil,
                fields: [:]
            )),
            recognitionStatus: .recognized,
            updatedAt: start,
            customFields: customFields
        )
    }

    private func item(
        id: String,
        start: Date,
        kind: TimelineKind
    ) -> TimelineItem {
        TimelineItem(
            id: id,
            sourceIdentifier: id,
            title: id,
            startDate: start,
            endDate: start.addingTimeInterval(30),
            isAllDay: false,
            source: .external,
            kind: kind,
            location: nil,
            notes: nil
        )
    }
}

private enum TimelineManagerTestError: Error {
    case load
}

private actor TimelineManagerTestGateway: EventKitGatewayProtocol {
    let events: [EventRecord]

    init(events: [EventRecord] = []) {
        self.events = events
    }

    func authorization() -> SourceAuthorization {
        .init(
            calendar: events.isEmpty ? .denied : .fullAccess,
            reminders: .denied
        )
    }

    func requestCalendarAccess() throws -> Bool { false }
    func requestReminderAccess() throws -> Bool { false }

    func fetchToday(
        calendar: Calendar,
        now: Date
    ) throws -> [EventRecord] {
        events
    }

    func fetchEvents(
        in interval: DateInterval,
        calendar: Calendar
    ) throws -> [EventRecord] {
        events
    }

    func fetchReminders(
        calendar: Calendar,
        now: Date
    ) throws -> [ReminderRecord] {
        []
    }
}

private actor TimelineManagerTestRecognizer: SystemEventRecognizing {
    let items: [TimelineItem]
    let templates: [String: TimelineEventTemplate]

    init(
        items: [TimelineItem],
        templates: [String: TimelineEventTemplate] = [:]
    ) {
        self.items = items
        self.templates = templates
    }

    func cachedSystemTemplates() -> [String: TimelineEventTemplate] {
        templates
    }

    func synchronize(
        events: [EventRecord],
        reminders: [ReminderRecord],
        settings: TimelineSettings,
        now: Date
    ) -> [String: TimelineEventTemplate] {
        [:]
    }

    func recognizedImageItems(
        settings: TimelineSettings,
        now: Date
    ) -> [TimelineItem] {
        items
    }
}

private actor TimelineManagerTestLocalCards: LocalTimelineCardManaging {
    let records: [StoredEventRecord]
    let loadError: Error?

    init(records: [StoredEventRecord], loadError: Error?) {
        self.records = records
        self.loadError = loadError
    }

    func loadAll() throws -> [StoredEventRecord] {
        if let loadError {
            throw loadError
        }
        return records
    }

    func update(_ record: StoredEventRecord) throws {}
    func delete(id: String) throws {}
}
