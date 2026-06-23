import XCTest
import UIKit
@testable import NowTimeline
@testable import NowTimelineCore

final class SettingsViewModelTests: XCTestCase {
    @MainActor
    func testTogglingSourceAndTimelineSettingsPersistsAndNotifiesOnce() {
        let store = makeStore()
        var refreshCount = 0
        let viewModel = SettingsViewModel(
            settingsStore: store,
            authorization: .init(calendar: .fullAccess, reminders: .fullAccess),
            onSettingsChanged: {
                refreshCount += 1
            },
            openURL: { _ in }
        )

        viewModel.setCalendarEnabled(false)
        viewModel.setShowTravelEvents(false)
        viewModel.setReminderDurationMinutes(45)

        XCTAssertEqual(refreshCount, 3)
        XCTAssertFalse(store.value.calendarEnabled)
        XCTAssertFalse(store.value.showTravelEvents)
        XCTAssertEqual(store.value.reminderDurationMinutes, 45)
    }

    @MainActor
    func testDeniedSourceRequestsSystemSettingsURL() {
        let store = makeStore()
        var openedURL: URL?
        let viewModel = SettingsViewModel(
            settingsStore: store,
            authorization: .init(calendar: .denied, reminders: .restricted),
            onSettingsChanged: {},
            openURL: { openedURL = $0 }
        )

        viewModel.openSourceSettings(for: .calendar)
        viewModel.openSourceSettings(for: .reminder)

        XCTAssertEqual(
            openedURL,
            URL(string: UIApplication.openSettingsURLString)
        )
    }

    @MainActor
    func testTurningSourceOffDoesNotChangeAuthorizationState() {
        let store = makeStore()
        let authorization = SourceAuthorization(
            calendar: .fullAccess,
            reminders: .denied
        )
        let viewModel = SettingsViewModel(
            settingsStore: store,
            authorization: authorization,
            onSettingsChanged: {},
            openURL: { _ in }
        )

        viewModel.setRemindersEnabled(false)

        XCTAssertEqual(viewModel.authorization, authorization)
        XCTAssertFalse(store.value.remindersEnabled)
    }

    @MainActor
    func testLiveActivityRowStatusReflectsPreferenceState() {
        let store = makeStore()
        let viewModel = SettingsViewModel(
            settingsStore: store,
            authorization: .init(calendar: .fullAccess, reminders: .fullAccess),
            onSettingsChanged: {},
            openURL: { _ in }
        )

        XCTAssertEqual(viewModel.liveActivityStatusText, "尚未启用")
        store.update { $0.liveActivityEnabled = true }
        XCTAssertEqual(viewModel.liveActivityStatusText, "等待接入")
    }

    @MainActor
    private func makeStore() -> SettingsStore {
        SettingsStore(
            defaults: UserDefaults(
                suiteName: "SettingsViewModelTests.\(UUID().uuidString)"
            )!
        )
    }
}
