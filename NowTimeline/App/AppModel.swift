import EventKit
import Foundation
import Observation

@MainActor
@Observable
final class AppModel {
    let dependencies: AppDependencies
    let todayViewModel: TodayViewModel

    private let notificationCenter: NotificationCenter
    private nonisolated let lifetime: AppModelLifetime

    init(
        dependencies: AppDependencies,
        notificationCenter: NotificationCenter = .default
    ) {
        self.dependencies = dependencies
        todayViewModel = TodayViewModel(dependencies: dependencies)
        self.notificationCenter = notificationCenter
        lifetime = AppModelLifetime(notificationCenter: notificationCenter)
    }

    func start() {
        if !lifetime.hasEventStoreObserver {
            let observer = notificationCenter.addObserver(
                forName: .EKEventStoreChanged,
                object: nil,
                queue: .main
            ) { [weak self] _ in
                Task { @MainActor [weak self] in
                    self?.scheduleRefresh()
                }
            }
            lifetime.installEventStoreObserver(observer)
        }
        scheduleRefresh()
    }

    func becameActive() {
        scheduleRefresh()
    }

    func relevantSettingsDidChange() {
        scheduleRefresh()
    }

    func refresh() async {
        await todayViewModel.refresh()
    }

    private func scheduleRefresh() {
        let task = Task { [weak self] in
            guard let self else {
                return
            }
            await todayViewModel.refresh()
        }
        lifetime.replaceRefreshTask(with: task)
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

    var hasEventStoreObserver: Bool {
        lock.withLock { eventStoreObserver != nil }
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
