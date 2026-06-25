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

        XCTAssertEqual(viewModel.liveActivityStatusText, "已暂停")
        store.update { $0.liveActivityEnabled = true }
        XCTAssertEqual(viewModel.liveActivityStatusText, "等待内容")
        XCTAssertFalse(viewModel.liveActivityDescriptionText.contains("尚未接入 ActivityKit"))
    }

    @MainActor
    func testLiveActivityRowUsesKnownRuntimeStatusWhenEnabled() {
        let store = makeStore()
        store.update { $0.liveActivityEnabled = true }

        let unavailable = SettingsViewModel(
            settingsStore: store,
            authorization: .init(calendar: .fullAccess, reminders: .fullAccess),
            liveActivityStatusText: { "暂不可用" },
            onSettingsChanged: {},
            openURL: { _ in }
        )
        XCTAssertEqual(unavailable.liveActivityStatusText, "暂不可用")

        let running = SettingsViewModel(
            settingsStore: store,
            authorization: .init(calendar: .fullAccess, reminders: .fullAccess),
            liveActivityStatusText: { "运行中" },
            onSettingsChanged: {},
            openURL: { _ in }
        )
        XCTAssertEqual(running.liveActivityStatusText, "运行中")

        store.update { $0.liveActivityEnabled = false }
        XCTAssertEqual(running.liveActivityStatusText, "已暂停")
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
        let keyStore = InMemoryAPIKeyStore()
        let viewModel = SettingsViewModel(
            settingsStore: store,
            authorization: .init(calendar: .fullAccess, reminders: .fullAccess),
            apiKeyStore: keyStore,
            onSettingsChanged: {},
            openURL: { _ in }
        )

        XCTAssertEqual(viewModel.openAIAPIKeyStatusText, "未配置")

        try viewModel.saveOpenAIAPIKey(" sk-test ")

        XCTAssertEqual(try keyStore.loadOpenAIAPIKey(), "sk-test")
        XCTAssertTrue(store.value.openAIAPIKeyConfigured)
        XCTAssertEqual(viewModel.openAIAPIKeyStatusText, "已配置")

        try viewModel.clearOpenAIAPIKey()

        XCTAssertNil(try keyStore.loadOpenAIAPIKey())
        XCTAssertFalse(store.value.openAIAPIKeyConfigured)
        XCTAssertEqual(viewModel.openAIAPIKeyStatusText, "未配置")
    }

    @MainActor
    func testImageRecognitionUpdatesStatusAndCallsRecognizer() async throws {
        let store = makeStore()
        store.update { $0.aiRecognitionMode = .openAI }
        let recognizer = RecordingImageRecognizer()
        let viewModel = SettingsViewModel(
            settingsStore: store,
            authorization: .init(calendar: .fullAccess, reminders: .fullAccess),
            imageRecognizer: recognizer,
            onSettingsChanged: {},
            openURL: { _ in }
        )

        try await viewModel.recognizeImportedImage(
            Data([1, 2, 3]),
            filename: "ticket.jpg"
        )

        XCTAssertEqual(viewModel.imageRecognitionStatusText, "图片识别完成")
        let calls = await recognizer.calls()
        XCTAssertEqual(calls.map(\.source), [.importedImage])
        XCTAssertEqual(calls.first?.filename, "ticket.jpg")
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

private actor RecordingImageRecognizer: ImageRecognizing {
    struct Call: Sendable {
        let data: Data
        let source: RecognitionSource
        let filename: String?
        let settings: TimelineSettings
    }

    private var recordedCalls: [Call] = []

    func recognizeImage(
        data: Data,
        source: RecognitionSource,
        filename: String?,
        settings: TimelineSettings,
        now: Date
    ) async throws -> StoredEventRecord {
        recordedCalls.append(
            .init(data: data, source: source, filename: filename, settings: settings)
        )
        return StoredEventRecord(
            id: "image:test",
            source: source,
            sourceIdentifier: "test",
            rawTitle: filename,
            rawLocation: nil,
            rawNotes: nil,
            imageReference: "Images/test.jpg",
            startDate: nil,
            endDate: nil,
            template: nil,
            recognitionStatus: .recognized,
            updatedAt: now
        )
    }

    func calls() -> [Call] {
        recordedCalls
    }
}
