import Foundation
import NowTimelineCore
import Observation
import XCTest
@testable import NowTimeline

final class SettingsStoreTests: XCTestCase {
    @MainActor
    func testAppGroupFactoryThrowsWhenSuiteIsUnavailable() {
        XCTAssertThrowsError(
            try SettingsStore.appGroupStore { _ in nil }
        ) { error in
            guard case SettingsStoreError.appGroupUnavailable = error else {
                return XCTFail("Unexpected error: \(error)")
            }
        }
    }

    @MainActor
    func testLoadsDefaultSettingsWhenNoDataExists() {
        let defaults = makeDefaults()

        let store = SettingsStore(defaults: defaults)

        XCTAssertEqual(store.value, TimelineSettings())
    }

    @MainActor
    func testUpdatePersistsAndReloadsExactSettings() {
        let defaults = makeDefaults()
        let expected = TimelineSettings(
            calendarEnabled: false,
            remindersEnabled: false,
            showTravelEvents: false,
            reminderDurationMinutes: 45,
            manualPinnedSourceIdentifier: "calendar:event-1",
            liveActivityEnabled: true
        )
        let store = SettingsStore(defaults: defaults)

        store.update { $0 = expected }

        XCTAssertEqual(store.value, expected)
        XCTAssertEqual(SettingsStore(defaults: defaults).value, expected)
    }

    @MainActor
    func testManualPinCanBeSetAndCleared() {
        let defaults = makeDefaults()
        let store = SettingsStore(defaults: defaults)

        store.update {
            $0.manualPinnedSourceIdentifier = "reminder:task-1"
        }
        XCTAssertEqual(
            SettingsStore(defaults: defaults)
                .value.manualPinnedSourceIdentifier,
            "reminder:task-1"
        )

        store.update { $0.manualPinnedSourceIdentifier = nil }
        XCTAssertNil(
            SettingsStore(defaults: defaults)
                .value.manualPinnedSourceIdentifier
        )
    }

    @MainActor
    func testInvalidReminderDurationsNormalizeToThirty() {
        let defaults = makeDefaults()

        for invalidDuration in [-1, 0, 14, 16, 29, 31, 59, 61] {
            let store = SettingsStore(defaults: defaults)

            store.update {
                $0.reminderDurationMinutes = invalidDuration
            }

            XCTAssertEqual(store.value.reminderDurationMinutes, 30)
            XCTAssertEqual(
                SettingsStore(defaults: defaults)
                    .value.reminderDurationMinutes,
                30
            )
        }
    }

    @MainActor
    func testValidReminderDurationsArePreserved() {
        let defaults = makeDefaults()

        for validDuration in [15, 30, 45, 60] {
            let store = SettingsStore(defaults: defaults)

            store.update {
                $0.reminderDurationMinutes = validDuration
            }

            XCTAssertEqual(
                SettingsStore(defaults: defaults)
                    .value.reminderDurationMinutes,
                validDuration
            )
        }
    }

    @MainActor
    func testCorruptDataFallsBackToDefaultsAndNextUpdateRepairsIt() throws {
        let defaults = makeDefaults()
        defaults.set(
            Data("not valid JSON".utf8),
            forKey: "timeline.settings.v1"
        )

        let store = SettingsStore(defaults: defaults)

        XCTAssertEqual(store.value, TimelineSettings())

        store.update { $0.calendarEnabled = false }

        let repairedData = try XCTUnwrap(
            defaults.data(forKey: "timeline.settings.v1")
        )
        let repairedSettings = try JSONDecoder().decode(
            TimelineSettings.self,
            from: repairedData
        )
        XCTAssertEqual(repairedSettings, store.value)
        XCTAssertFalse(repairedSettings.calendarEnabled)
    }

    @MainActor
    func testMutationNotifiesObserversOnMainActor() {
        let defaults = makeDefaults()
        let store = SettingsStore(defaults: defaults)
        let changed = expectation(description: "settings changed")

        withObservationTracking {
            _ = store.value
        } onChange: {
            MainActor.assumeIsolated {
                changed.fulfill()
            }
        }

        store.update { $0.liveActivityEnabled = true }

        wait(for: [changed], timeout: 1)
        XCTAssertTrue(store.value.liveActivityEnabled)
    }

    private func makeDefaults() -> UserDefaults {
        let suiteName = "SettingsStoreTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        addTeardownBlock {
            UserDefaults(suiteName: suiteName)?
                .removePersistentDomain(forName: suiteName)
        }
        return defaults
    }
}
