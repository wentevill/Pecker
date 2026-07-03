import XCTest
import UIKit
@testable import Pecker
@testable import PeckerCore

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

        XCTAssertEqual(refreshCount, 2)
        XCTAssertFalse(store.value.calendarEnabled)
        XCTAssertFalse(store.value.showTravelEvents)
    }

    @MainActor
    func testLanguageSettingPersistsAndNotifies() {
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

        viewModel.setLanguage(.english)

        XCTAssertEqual(refreshCount, 1)
        XCTAssertEqual(store.value.language, .english)
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
        let localizer = AppLocalizer(language: .simplifiedChinese)
        let viewModel = SettingsViewModel(
            settingsStore: store,
            authorization: .init(calendar: .fullAccess, reminders: .fullAccess),
            onSettingsChanged: {},
            openURL: { _ in }
        )

        XCTAssertEqual(
            viewModel.liveActivityStatusText(localizer: localizer),
            "\u{5df2}\u{6682}\u{505c}"
        )
        store.update { $0.liveActivityEnabled = true }
        XCTAssertEqual(
            viewModel.liveActivityStatusText(localizer: localizer),
            "\u{7b49}\u{5f85}\u{5185}\u{5bb9}"
        )
        XCTAssertFalse(
            viewModel.liveActivityDescriptionText(localizer: localizer)
                .contains("\u{5c1a}\u{672a}\u{63a5}\u{5165} ActivityKit")
        )
    }

    @MainActor
    func testLiveActivityRowUsesKnownRuntimeStatusWhenEnabled() {
        let store = makeStore()
        let localizer = AppLocalizer(language: .simplifiedChinese)
        store.update { $0.liveActivityEnabled = true }

        let unavailable = SettingsViewModel(
            settingsStore: store,
            authorization: .init(calendar: .fullAccess, reminders: .fullAccess),
            liveActivityStatusText: { "unavailable" },
            onSettingsChanged: {},
            openURL: { _ in }
        )
        XCTAssertEqual(
            unavailable.liveActivityStatusText(localizer: localizer),
            "\u{6682}\u{4e0d}\u{53ef}\u{7528}"
        )

        let running = SettingsViewModel(
            settingsStore: store,
            authorization: .init(calendar: .fullAccess, reminders: .fullAccess),
            liveActivityStatusText: { "running" },
            onSettingsChanged: {},
            openURL: { _ in }
        )
        XCTAssertEqual(
            running.liveActivityStatusText(localizer: localizer),
            "\u{8fd0}\u{884c}\u{4e2d}"
        )

        store.update { $0.liveActivityEnabled = false }
        XCTAssertEqual(
            running.liveActivityStatusText(localizer: localizer),
            "\u{5df2}\u{6682}\u{505c}"
        )
    }

    @MainActor
    func testAISettingsPersistAndNotifyChanges() {
        let store = makeStore()
        var refreshCount = 0
        let viewModel = SettingsViewModel(
            settingsStore: store,
            authorization: .init(calendar: .fullAccess, reminders: .fullAccess),
            onSettingsChanged: { refreshCount += 1 },
            openURL: { _ in }
        )

        viewModel.setAIRecognitionMode(.openAI)
        viewModel.setOpenAIHost(" https://proxy.example.com ")
        viewModel.setOpenAIModel(" gpt-test ")
        viewModel.setSyncCalendarToStorage(true)
        viewModel.setSyncRemindersToStorage(true)

        XCTAssertEqual(refreshCount, 5)
        XCTAssertEqual(store.value.aiRecognitionMode, .openAI)
        XCTAssertEqual(store.value.openAIHost, "https://proxy.example.com")
        XCTAssertEqual(store.value.openAIModel, "gpt-test")
        XCTAssertTrue(store.value.syncCalendarToStorage)
        XCTAssertTrue(store.value.syncRemindersToStorage)
    }

    @MainActor
    func testOpenAIAPIKeyStatusIsStoredOutsideSettingsPayload() throws {
        let store = makeStore()
        let localizer = AppLocalizer(language: .simplifiedChinese)
        let keyStore = InMemoryAPIKeyStore()
        let viewModel = SettingsViewModel(
            settingsStore: store,
            authorization: .init(calendar: .fullAccess, reminders: .fullAccess),
            apiKeyStore: keyStore,
            onSettingsChanged: {},
            openURL: { _ in }
        )

        XCTAssertEqual(
            viewModel.openAIAPIKeyStatusText(localizer: localizer),
            "\u{672a}\u{914d}\u{7f6e}"
        )

        try viewModel.saveOpenAIAPIKey(" sk-test ")

        XCTAssertEqual(try keyStore.loadOpenAIAPIKey(), "sk-test")
        XCTAssertTrue(store.value.openAIAPIKeyConfigured)
        XCTAssertEqual(
            viewModel.openAIAPIKeyStatusText(localizer: localizer),
            "\u{5df2}\u{914d}\u{7f6e}"
        )

        try viewModel.clearOpenAIAPIKey()

        XCTAssertNil(try keyStore.loadOpenAIAPIKey())
        XCTAssertFalse(store.value.openAIAPIKeyConfigured)
        XCTAssertEqual(
            viewModel.openAIAPIKeyStatusText(localizer: localizer),
            "\u{672a}\u{914d}\u{7f6e}"
        )
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

private final class InMemoryAPIKeyStore: APIKeyStoring, @unchecked Sendable {
    private var key: String?

    func saveOpenAIAPIKey(_ key: String) throws {
        self.key = key
    }

    func loadOpenAIAPIKey() throws -> String? {
        key
    }

    func clearOpenAIAPIKey() throws {
        key = nil
    }
}
