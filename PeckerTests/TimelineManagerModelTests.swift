import Foundation
import PeckerCore
import XCTest
@testable import Pecker

final class TimelineManagerModelTests: XCTestCase {
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
    func authorization() -> SourceAuthorization {
        .init(calendar: .denied, reminders: .denied)
    }

    func requestCalendarAccess() throws -> Bool { false }
    func requestReminderAccess() throws -> Bool { false }

    func fetchToday(
        calendar: Calendar,
        now: Date
    ) throws -> [EventRecord] {
        []
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

    init(items: [TimelineItem]) {
        self.items = items
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
