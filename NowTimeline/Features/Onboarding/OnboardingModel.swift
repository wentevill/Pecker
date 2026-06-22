import Foundation
import Observation

enum OnboardingStep: Int, CaseIterable, Equatable {
    case welcome
    case calendar
    case reminders
    case liveActivityIntroduction
    case complete

    var progress: Int {
        min(rawValue + 1, 4)
    }
}

enum PermissionRequestStatus: Equatable {
    case notRequested
    case granted
    case denied
    case failed
}

@MainActor
@Observable
final class OnboardingModel {
    static let completionKey = "onboarding.completed.v1"

    private(set) var currentStep: OnboardingStep
    private(set) var isBusy = false
    private(set) var calendarStatus: PermissionRequestStatus = .notRequested
    private(set) var reminderStatus: PermissionRequestStatus = .notRequested
    private(set) var errorMessage: String?

    private let gateway: any EventKitGatewayProtocol
    private let settingsStore: SettingsStore
    private let defaults: UserDefaults

    init(
        gateway: any EventKitGatewayProtocol,
        settingsStore: SettingsStore,
        defaults: UserDefaults,
        completionOverride: Bool? = nil
    ) {
        self.gateway = gateway
        self.settingsStore = settingsStore
        self.defaults = defaults
        let isComplete = completionOverride
            ?? defaults.bool(forKey: Self.completionKey)
        currentStep = isComplete ? .complete : .welcome
    }

    var isComplete: Bool {
        currentStep == .complete
    }

    func performPrimaryAction() async {
        guard !isBusy else {
            return
        }

        switch currentStep {
        case .welcome:
            currentStep = .calendar
        case .calendar:
            await requestCalendar()
        case .reminders:
            await requestReminders()
        case .liveActivityIntroduction:
            complete(liveActivityEnabled: true)
        case .complete:
            break
        }
    }

    func skipCurrentPermission() {
        guard !isBusy else {
            return
        }

        switch currentStep {
        case .calendar:
            currentStep = .reminders
        case .reminders:
            currentStep = .liveActivityIntroduction
        case .welcome, .liveActivityIntroduction, .complete:
            break
        }
    }

    func completeWithoutLiveActivity() {
        guard currentStep == .liveActivityIntroduction, !isBusy else {
            return
        }
        complete(liveActivityEnabled: false)
    }

    private func requestCalendar() async {
        isBusy = true
        errorMessage = nil
        defer {
            isBusy = false
            currentStep = .reminders
        }

        do {
            calendarStatus = try await gateway.requestCalendarAccess()
                ? .granted
                : .denied
        } catch {
            calendarStatus = .failed
            errorMessage = "无法访问日历，请稍后在系统设置中重试。"
        }
    }

    private func requestReminders() async {
        isBusy = true
        errorMessage = nil
        defer {
            isBusy = false
            currentStep = .liveActivityIntroduction
        }

        do {
            reminderStatus = try await gateway.requestReminderAccess()
                ? .granted
                : .denied
        } catch {
            reminderStatus = .failed
            errorMessage = "无法访问提醒事项，请稍后在系统设置中重试。"
        }
    }

    private func complete(liveActivityEnabled: Bool) {
        settingsStore.update {
            $0.liveActivityEnabled = liveActivityEnabled
        }
        defaults.set(true, forKey: Self.completionKey)
        currentStep = .complete
    }
}
