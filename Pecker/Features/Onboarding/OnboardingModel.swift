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

    @discardableResult
    func performPrimaryAction(
        expectedStep: OnboardingStep? = nil
    ) async -> Bool {
        let expectedStep = expectedStep ?? currentStep
        errorMessage = nil
        guard !isBusy, currentStep == expectedStep else {
            return false
        }

        switch expectedStep {
        case .welcome:
            currentStep = .calendar
            return true
        case .calendar:
            return await requestCalendar(expectedStep: expectedStep)
        case .reminders:
            return await requestReminders(expectedStep: expectedStep)
        case .liveActivityIntroduction:
            return complete(
                liveActivityEnabled: true,
                expectedStep: expectedStep
            )
        case .complete:
            return false
        }
    }

    @discardableResult
    func skipCurrentPermission(expectedStep: OnboardingStep? = nil) -> Bool {
        let expectedStep = expectedStep ?? currentStep
        errorMessage = nil
        guard !isBusy, currentStep == expectedStep else {
            return false
        }

        switch expectedStep {
        case .calendar:
            currentStep = .reminders
            return true
        case .reminders:
            currentStep = .liveActivityIntroduction
            return true
        case .welcome, .liveActivityIntroduction, .complete:
            return false
        }
    }

    @discardableResult
    func completeWithoutLiveActivity(
        expectedStep: OnboardingStep? = nil
    ) -> Bool {
        let expectedStep = expectedStep ?? currentStep
        errorMessage = nil
        guard !isBusy, currentStep == expectedStep else {
            return false
        }
        return complete(
            liveActivityEnabled: false,
            expectedStep: expectedStep
        )
    }

    private func requestCalendar(
        expectedStep: OnboardingStep
    ) async -> Bool {
        isBusy = true
        defer {
            isBusy = false
            if currentStep == expectedStep {
                currentStep = .reminders
            }
        }

        do {
            calendarStatus = try await gateway.requestCalendarAccess()
                ? .granted
                : .denied
        } catch {
            calendarStatus = .failed
            errorMessage = "\u{65e0}\u{6cd5}\u{8bbf}\u{95ee}\u{65e5}\u{5386}，\u{8bf7}\u{7a0d}\u{540e}\u{5728}\u{7cfb}\u{7edf}\u{8bbe}\u{7f6e}\u{4e2d}\u{91cd}\u{8bd5}。"
        }

        return true
    }

    private func requestReminders(
        expectedStep: OnboardingStep
    ) async -> Bool {
        isBusy = true
        defer {
            isBusy = false
            if currentStep == expectedStep {
                currentStep = .liveActivityIntroduction
            }
        }

        do {
            reminderStatus = try await gateway.requestReminderAccess()
                ? .granted
                : .denied
        } catch {
            reminderStatus = .failed
            errorMessage = "\u{65e0}\u{6cd5}\u{8bbf}\u{95ee}\u{63d0}\u{9192}\u{4e8b}\u{9879}，\u{8bf7}\u{7a0d}\u{540e}\u{5728}\u{7cfb}\u{7edf}\u{8bbe}\u{7f6e}\u{4e2d}\u{91cd}\u{8bd5}。"
        }

        return true
    }

    private func complete(
        liveActivityEnabled: Bool,
        expectedStep: OnboardingStep
    ) -> Bool {
        guard currentStep == expectedStep,
              expectedStep == .liveActivityIntroduction else {
            return false
        }
        settingsStore.update {
            $0.liveActivityEnabled = liveActivityEnabled
        }
        defaults.set(true, forKey: Self.completionKey)
        currentStep = .complete
        return true
    }
}
