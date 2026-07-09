import EventKit
import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    let dependencies: AppDependencies
    let todayViewModel: TodayViewModel
    let onboardingModel: OnboardingModel

    private let notificationCenter: NotificationCenter
    private let refreshOperation: @MainActor () async -> Void
    private nonisolated let lifetime: AppModelLifetime
    @ObservationIgnored
    private let liveActivityBoundaryScheduler: LiveActivityBoundaryScheduler
    private(set) var hasStarted = false
    private var isActive = false

    var onboardingCompleted: Bool {
        onboardingModel.isComplete
    }

    init(
        dependencies: AppDependencies,
        onboardingDefaults: UserDefaults,
        notificationCenter: NotificationCenter = .default,
        refreshOperation: (@MainActor () async -> Void)? = nil
    ) {
        self.dependencies = dependencies
        let todayViewModel = TodayViewModel(dependencies: dependencies)
        self.todayViewModel = todayViewModel
        onboardingModel = OnboardingModel(
            gateway: dependencies.gateway,
            notificationScheduler: dependencies.notificationScheduler,
            settingsStore: dependencies.settingsStore,
            defaults: onboardingDefaults
        )
        self.notificationCenter = notificationCenter
        let resolvedRefreshOperation = refreshOperation ?? {
            await todayViewModel.refresh()
        }
        self.refreshOperation = resolvedRefreshOperation
        liveActivityBoundaryScheduler = LiveActivityBoundaryScheduler {
            await resolvedRefreshOperation()
            return todayViewModel.nextLiveActivityBoundary
        }
        lifetime = AppModelLifetime(notificationCenter: notificationCenter)
    }

    func start() {
        guard onboardingCompleted, !hasStarted else {
            return
        }

        hasStarted = true
        isActive = true
        let observer = notificationCenter.addObserver(
            forName: .EKEventStoreChanged,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            Task { @MainActor [weak self] in
                self?.eventStoreDidChange()
            }
        }
        lifetime.installEventStoreObserver(observer)
        scheduleRefresh()
    }

    func becameActive() {
        guard !isActive else {
            return
        }
        isActive = true
        guard hasStarted else {
            return
        }
        scheduleRefresh()
    }

    func becameInactive() {
        isActive = false
        try? liveActivityBoundaryScheduler.becameInactive()
    }

    func settingsChanged() {
        if hasStarted {
            scheduleRefresh()
        }
    }

    func relevantSettingsDidChange() {
        settingsChanged()
    }

    func refresh() async {
        await todayViewModel.refresh()
        liveActivityBoundaryScheduler.schedule(
            todayViewModel.nextLiveActivityBoundary
        )
    }

    func handleLiveActivityBackgroundRefresh() async {
        guard onboardingCompleted else {
            return
        }
        await refreshOperation()
        guard !Task.isCancelled else {
            return
        }
        liveActivityBoundaryScheduler.schedule(
            todayViewModel.nextLiveActivityBoundary
        )
        try? liveActivityBoundaryScheduler.becameInactive()
    }

    private func scheduleRefresh() {
        let task = Task { [weak self] in
            guard let self else {
                return
            }
            await refreshOperation()
            guard !Task.isCancelled else {
                return
            }
            liveActivityBoundaryScheduler.schedule(
                todayViewModel.nextLiveActivityBoundary
            )
        }
        lifetime.replaceRefreshTask(with: task)
    }

    private func eventStoreDidChange() {
        if hasStarted {
            scheduleRefresh()
        }
    }

    deinit {
        lifetime.cancel()
    }
}

private final class AppModelLifetime: @unchecked Sendable {
    private let lock = NSLock()
    private let notificationCenter: NotificationCenter
    private var eventStoreObserver: NSObjectProtocol?
    private var refreshTask: Task<Void, Never>?

    init(notificationCenter: NotificationCenter) {
        self.notificationCenter = notificationCenter
    }

    func installEventStoreObserver(_ observer: NSObjectProtocol) {
        lock.withLock {
            eventStoreObserver = observer
        }
    }

    func replaceRefreshTask(with task: Task<Void, Never>) {
        let previousTask = lock.withLock {
            let previousTask = refreshTask
            refreshTask = task
            return previousTask
        }
        previousTask?.cancel()
    }

    func cancel() {
        let resources = lock.withLock {
            let resources = (refreshTask, eventStoreObserver)
            refreshTask = nil
            eventStoreObserver = nil
            return resources
        }
        resources.0?.cancel()
        if let observer = resources.1 {
            notificationCenter.removeObserver(observer)
        }
    }
}
