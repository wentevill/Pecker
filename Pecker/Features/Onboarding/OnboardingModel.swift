import Foundation
import Observation

enum OnboardingStep: Int, CaseIterable, Equatable {
    case welcome
    case calendar
    case reminders
    case notifications
    case liveActivityIntroduction
    case complete

    var progress: Int {
        min(rawValue + 1, 5)
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
    private(set) var notificationStatus: PermissionRequestStatus = .notRequested
    private(set) var errorMessage: String?

    private let gateway: any EventKitGatewayProtocol
    private let notificationScheduler: any TimelineNotificationScheduling
    private let settingsStore: SettingsStore
    private let defaults: UserDefaults

    init(
        gateway: any EventKitGatewayProtocol,
        notificationScheduler: any TimelineNotificationScheduling = UserNotificationScheduler(),
        settingsStore: SettingsStore,
        defaults: UserDefaults,
        completionOverride: Bool? = nil
    ) {
        self.gateway = gateway
        self.notificationScheduler = notificationScheduler
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
        case .notifications:
            return await requestNotifications(expectedStep: expectedStep)
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
            currentStep = .notifications
            return true
        case .notifications:
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
            errorMessage = AppLocalizer(
                language: settingsStore.value.language
            ).string("onboarding.calendar.error")
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
                currentStep = .notifications
            }
        }

        do {
            reminderStatus = try await gateway.requestReminderAccess()
                ? .granted
                : .denied
        } catch {
            reminderStatus = .failed
            errorMessage = AppLocalizer(
                language: settingsStore.value.language
            ).string("onboarding.reminders.error")
        }

        return true
    }

    private func requestNotifications(
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
            let granted = try await notificationScheduler.requestAuthorization()
            notificationStatus = granted ? .granted : .denied
            settingsStore.update {
                $0.notificationsEnabled = granted
            }
        } catch {
            notificationStatus = .failed
            settingsStore.update {
                $0.notificationsEnabled = false
            }
            errorMessage = AppLocalizer(
                language: settingsStore.value.language
            ).string("onboarding.notifications.error")
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
