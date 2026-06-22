import Foundation
import NowTimelineCore
import XCTest
@testable import NowTimeline

final class OnboardingStateTests: XCTestCase {
    @MainActor
    func testInitialStateStartsAtWelcomeWithoutRequestingPermission() async {
        let fixture = makeFixture()

        XCTAssertEqual(fixture.model.currentStep, .welcome)
        XCTAssertFalse(fixture.model.isBusy)
        XCTAssertEqual(fixture.model.calendarStatus, .notRequested)
        XCTAssertEqual(fixture.model.reminderStatus, .notRequested)
        XCTAssertNil(fixture.model.errorMessage)
        let requestCounts = await fixture.gateway.requestCounts()
        XCTAssertEqual(requestCounts, .init())
    }

    @MainActor
    func testWelcomePrimaryActionAdvancesToCalendar() async {
        let fixture = makeFixture()

        await fixture.model.performPrimaryAction()

        XCTAssertEqual(fixture.model.currentStep, .calendar)
        let requestCounts = await fixture.gateway.requestCounts()
        XCTAssertEqual(requestCounts, .init())
    }

    @MainActor
    func testCalendarRequestOccursOnlyOnPrimaryActionAndGrantedAdvances() async {
        let fixture = makeFixture(calendarResult: .success(true))
        await fixture.model.performPrimaryAction()

        let initialRequestCounts = await fixture.gateway.requestCounts()
        XCTAssertEqual(initialRequestCounts, .init())

        await fixture.model.performPrimaryAction()

        XCTAssertEqual(fixture.model.currentStep, .reminders)
        XCTAssertEqual(fixture.model.calendarStatus, .granted)
        let requestCounts = await fixture.gateway.requestCounts()
        XCTAssertEqual(requestCounts, .init(calendar: 1))
    }

    @MainActor
    func testCalendarDeniedAdvancesToReminders() async {
        let fixture = makeFixture(calendarResult: .success(false))
        await fixture.model.performPrimaryAction()

        await fixture.model.performPrimaryAction()

        XCTAssertEqual(fixture.model.currentStep, .reminders)
        XCTAssertEqual(fixture.model.calendarStatus, .denied)
    }

    @MainActor
    func testCalendarCanBeSkippedWithoutRequestingPermission() async {
        let fixture = makeFixture()
        await fixture.model.performPrimaryAction()

        fixture.model.skipCurrentPermission()

        XCTAssertEqual(fixture.model.currentStep, .reminders)
        let requestCounts = await fixture.gateway.requestCounts()
        XCTAssertEqual(requestCounts, .init())
    }

    @MainActor
    func testCalendarErrorAdvancesAndRecordsMessage() async {
        let fixture = makeFixture(calendarResult: .failure(TestError.calendar))
        await fixture.model.performPrimaryAction()

        await fixture.model.performPrimaryAction()

        XCTAssertEqual(fixture.model.currentStep, .reminders)
        XCTAssertEqual(fixture.model.calendarStatus, .failed)
        XCTAssertEqual(fixture.model.errorMessage, "无法访问日历，请稍后在系统设置中重试。")
    }

    @MainActor
    func testReminderGrantedAdvancesToLiveActivityIntroduction() async {
        let fixture = makeFixture(reminderResult: .success(true))
        await advanceToReminders(fixture.model)

        await fixture.model.performPrimaryAction()

        XCTAssertEqual(
            fixture.model.currentStep,
            .liveActivityIntroduction
        )
        XCTAssertEqual(fixture.model.reminderStatus, .granted)
        let requestCounts = await fixture.gateway.requestCounts()
        XCTAssertEqual(requestCounts, .init(calendar: 1, reminders: 1))
    }

    @MainActor
    func testReminderDeniedAdvancesToLiveActivityIntroduction() async {
        let fixture = makeFixture(reminderResult: .success(false))
        await advanceToReminders(fixture.model)

        await fixture.model.performPrimaryAction()

        XCTAssertEqual(
            fixture.model.currentStep,
            .liveActivityIntroduction
        )
        XCTAssertEqual(fixture.model.reminderStatus, .denied)
    }

    @MainActor
    func testRemindersCanBeSkippedWithoutRequestingPermission() async {
        let fixture = makeFixture()
        await fixture.model.performPrimaryAction()
        fixture.model.skipCurrentPermission()

        fixture.model.skipCurrentPermission()

        XCTAssertEqual(
            fixture.model.currentStep,
            .liveActivityIntroduction
        )
        let requestCounts = await fixture.gateway.requestCounts()
        XCTAssertEqual(requestCounts, .init())
    }

    @MainActor
    func testReminderErrorAdvancesAndRecordsMessage() async {
        let fixture = makeFixture(reminderResult: .failure(TestError.reminders))
        await advanceToReminders(fixture.model)

        await fixture.model.performPrimaryAction()

        XCTAssertEqual(
            fixture.model.currentStep,
            .liveActivityIntroduction
        )
        XCTAssertEqual(fixture.model.reminderStatus, .failed)
        XCTAssertEqual(fixture.model.errorMessage, "无法访问提醒事项，请稍后在系统设置中重试。")
    }

    @MainActor
    func testEnableLiveActivityPersistsSettingAndCompletion() async {
        let fixture = makeFixture()
        await advanceToLiveActivity(fixture.model)

        await fixture.model.performPrimaryAction()

        XCTAssertEqual(fixture.model.currentStep, .complete)
        XCTAssertTrue(fixture.settingsStore.value.liveActivityEnabled)
        XCTAssertTrue(
            fixture.defaults.bool(forKey: "onboarding.completed.v1")
        )
    }

    @MainActor
    func testEnableLaterDisablesSettingAndPersistsCompletion() async {
        let fixture = makeFixture(liveActivityEnabled: true)
        await advanceToLiveActivity(fixture.model)

        fixture.model.completeWithoutLiveActivity()

        XCTAssertEqual(fixture.model.currentStep, .complete)
        XCTAssertFalse(fixture.settingsStore.value.liveActivityEnabled)
        XCTAssertTrue(
            fixture.defaults.bool(forKey: "onboarding.completed.v1")
        )
    }

    @MainActor
    func testPersistedCompletionSkipsOnboardingOnNextModelCreation() async {
        let fixture = makeFixture()
        await advanceToLiveActivity(fixture.model)
        await fixture.model.performPrimaryAction()

        let nextModel = OnboardingModel(
            gateway: fixture.gateway,
            settingsStore: fixture.settingsStore,
            defaults: fixture.defaults
        )

        XCTAssertEqual(nextModel.currentStep, .complete)
        let requestCounts = await fixture.gateway.requestCounts()
        XCTAssertEqual(requestCounts, .init(calendar: 1, reminders: 1))
    }

    @MainActor
    func testDoubleTapWhileBusyDoesNotDuplicateCalendarRequest() async {
        let gateway = OnboardingGateway(calendarWaitsForRelease: true)
        let fixture = makeFixture(gateway: gateway)
        await fixture.model.performPrimaryAction()

        let firstTap = Task { await fixture.model.performPrimaryAction() }
        await gateway.waitForCalendarRequest()
        let secondTap = Task { await fixture.model.performPrimaryAction() }
        await secondTap.value

        XCTAssertTrue(fixture.model.isBusy)
        let requestCounts = await gateway.requestCounts()
        XCTAssertEqual(requestCounts, .init(calendar: 1))

        await gateway.releaseCalendarRequest()
        await firstTap.value
        XCTAssertEqual(fixture.model.currentStep, .reminders)
    }

    @MainActor
    func testAppModelDoesNotRefreshUntilOnboardingCompletes() async {
        let gateway = OnboardingGateway()
        let fixture = makeFixture(gateway: gateway)
        let appModel = AppModel(
            dependencies: fixture.dependencies,
            onboardingDefaults: fixture.defaults,
            notificationCenter: NotificationCenter()
        )

        appModel.start()
        appModel.becameActive()
        await Task.yield()

        let initialAuthorizationCount = await gateway.authorizationCount()
        XCTAssertEqual(initialAuthorizationCount, 0)

        await advanceToLiveActivity(appModel.onboardingModel)
        await appModel.onboardingModel.performPrimaryAction()
        appModel.onboardingDidComplete()
        await gateway.waitForAuthorization()

        let authorizationCount = await gateway.authorizationCount()
        XCTAssertEqual(authorizationCount, 1)
    }

    @MainActor
    private func advanceToReminders(_ model: OnboardingModel) async {
        await model.performPrimaryAction()
        await model.performPrimaryAction()
    }

    @MainActor
    private func advanceToLiveActivity(_ model: OnboardingModel) async {
        await advanceToReminders(model)
        await model.performPrimaryAction()
    }

    @MainActor
    private func makeFixture(
        gateway: OnboardingGateway? = nil,
        calendarResult: Result<Bool, Error> = .success(true),
        reminderResult: Result<Bool, Error> = .success(true),
        liveActivityEnabled: Bool = false
    ) -> Fixture {
        let suiteName = "OnboardingStateTests.\(UUID().uuidString)"
        let defaults = UserDefaults(suiteName: suiteName)!
        defaults.removePersistentDomain(forName: suiteName)
        addTeardownBlock {
            UserDefaults(suiteName: suiteName)?
                .removePersistentDomain(forName: suiteName)
        }
        let settingsStore = SettingsStore(defaults: defaults)
        settingsStore.update {
            $0.liveActivityEnabled = liveActivityEnabled
        }
        let gateway = gateway ?? OnboardingGateway(
            calendarResult: calendarResult,
            reminderResult: reminderResult
        )
        let dependencies = AppDependencies(
            gateway: gateway,
            mapper: EventKitMapper(),
            engine: .init(),
            snapshotStore: OnboardingSnapshotStore(),
            settingsStore: settingsStore,
            calendar: Calendar(identifier: .gregorian)
        )
        return Fixture(
            model: OnboardingModel(
                gateway: gateway,
                settingsStore: settingsStore,
                defaults: defaults
            ),
            gateway: gateway,
            settingsStore: settingsStore,
            defaults: defaults,
            dependencies: dependencies
        )
    }
}

private struct Fixture {
    let model: OnboardingModel
    let gateway: OnboardingGateway
    let settingsStore: SettingsStore
    let defaults: UserDefaults
    let dependencies: AppDependencies
}

private enum TestError: Error {
    case calendar
    case reminders
}

private actor OnboardingGateway: EventKitGatewayProtocol {
    struct RequestCounts: Equatable {
        var calendar = 0
        var reminders = 0
    }

    private let calendarResult: Result<Bool, Error>
    private let reminderResult: Result<Bool, Error>
    private let calendarWaitsForRelease: Bool
    private var counts = RequestCounts()
    private var authorizationCalls = 0
    private var calendarStarted = false
    private var calendarStartedContinuation: CheckedContinuation<Void, Never>?
    private var calendarReleaseContinuation: CheckedContinuation<Void, Never>?
    private var authorizationContinuation: CheckedContinuation<Void, Never>?

    init(
        calendarResult: Result<Bool, Error> = .success(true),
        reminderResult: Result<Bool, Error> = .success(true),
        calendarWaitsForRelease: Bool = false
    ) {
        self.calendarResult = calendarResult
        self.reminderResult = reminderResult
        self.calendarWaitsForRelease = calendarWaitsForRelease
    }

    func authorization() -> SourceAuthorization {
        authorizationCalls += 1
        authorizationContinuation?.resume()
        authorizationContinuation = nil
        return .init(calendar: .denied, reminders: .denied)
    }

    func requestCalendarAccess() async throws -> Bool {
        counts.calendar += 1
        calendarStarted = true
        calendarStartedContinuation?.resume()
        calendarStartedContinuation = nil
        if calendarWaitsForRelease {
            await withCheckedContinuation {
                calendarReleaseContinuation = $0
            }
        }
        return try calendarResult.get()
    }

    func requestReminderAccess() async throws -> Bool {
        counts.reminders += 1
        return try reminderResult.get()
    }

    func fetchToday(calendar: Calendar, now: Date) async throws -> [EventRecord] {
        []
    }

    func fetchReminders(
        calendar: Calendar,
        now: Date
    ) async throws -> [ReminderRecord] {
        []
    }

    func requestCounts() -> RequestCounts {
        counts
    }

    func authorizationCount() -> Int {
        authorizationCalls
    }

    func waitForCalendarRequest() async {
        if calendarStarted {
            return
        }
        await withCheckedContinuation {
            calendarStartedContinuation = $0
        }
    }

    func releaseCalendarRequest() {
        calendarReleaseContinuation?.resume()
        calendarReleaseContinuation = nil
    }

    func waitForAuthorization() async {
        if authorizationCalls > 0 {
            return
        }
        await withCheckedContinuation {
            authorizationContinuation = $0
        }
    }
}

private actor OnboardingSnapshotStore: SnapshotStoring {
    func load() -> SnapshotLoadResult {
        .missing
    }

    func save(_ snapshot: TodaySnapshot) {}
}
