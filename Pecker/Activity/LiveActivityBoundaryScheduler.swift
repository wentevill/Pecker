import BackgroundTasks
import Foundation

protocol LiveActivitySleeping: Sendable {
    func sleep(until date: Date) async throws
}

protocol LiveActivityBackgroundScheduling: Sendable {
    func submit(earliestBeginDate: Date?) throws
    func cancel()
}

struct ContinuousLiveActivitySleeper: LiveActivitySleeping {
    func sleep(until date: Date) async throws {
        let delay = max(date.timeIntervalSinceNow, 0)
        try await Task.sleep(for: .seconds(delay))
    }
}

struct NoopLiveActivityBackgroundScheduler:
    LiveActivityBackgroundScheduling
{
    func submit(earliestBeginDate: Date?) throws {}
    func cancel() {}
}

enum LiveActivityBackgroundTask {
    static let identifier =
        "com.wenttang.pecker.live-activity-refresh"
}

struct SystemLiveActivityBackgroundScheduler:
    LiveActivityBackgroundScheduling
{
    func submit(earliestBeginDate: Date?) throws {
        cancel()
        guard let earliestBeginDate else {
            return
        }
        let request = BGAppRefreshTaskRequest(
            identifier: LiveActivityBackgroundTask.identifier
        )
        request.earliestBeginDate = earliestBeginDate
        try BGTaskScheduler.shared.submit(request)
    }

    func cancel() {
        BGTaskScheduler.shared.cancel(
            taskRequestWithIdentifier: LiveActivityBackgroundTask.identifier
        )
    }
}

@MainActor
final class LiveActivityBoundaryScheduler {
    private let sleeper: any LiveActivitySleeping
    private let backgroundScheduler: any LiveActivityBackgroundScheduling
    private let now: @Sendable () -> Date
    private let refresh: @MainActor @Sendable () async -> Date?

    private var task: Task<Void, Never>?
    private(set) var boundary: Date?

    init(
        sleeper: any LiveActivitySleeping = ContinuousLiveActivitySleeper(),
        backgroundScheduler: any LiveActivityBackgroundScheduling =
            SystemLiveActivityBackgroundScheduler(),
        now: @escaping @Sendable () -> Date = { .now },
        refresh: @escaping @MainActor @Sendable () async -> Date?
    ) {
        self.sleeper = sleeper
        self.backgroundScheduler = backgroundScheduler
        self.now = now
        self.refresh = refresh
    }

    func schedule(_ boundary: Date?) {
        task?.cancel()
        task = nil
        self.boundary = boundary

        guard let boundary else {
            backgroundScheduler.cancel()
            return
        }

        if boundary <= now() {
            task = Task { [weak self, refresh] in
                let nextBoundary = await refresh()
                guard !Task.isCancelled else {
                    return
                }
                self?.schedule(nextBoundary)
            }
            return
        }

        let sleeper = self.sleeper
        let refresh = self.refresh
        task = Task { [weak self] in
            do {
                try await sleeper.sleep(until: boundary)
                try Task.checkCancellation()
                let nextBoundary = await refresh()
                try Task.checkCancellation()
                self?.schedule(nextBoundary)
            } catch {
                return
            }
        }
    }

    func becameActive() {
        schedule(boundary)
    }

    func becameInactive() throws {
        task?.cancel()
        task = nil
        try backgroundScheduler.submit(earliestBeginDate: boundary)
    }

    func cancel() {
        task?.cancel()
        task = nil
        boundary = nil
        backgroundScheduler.cancel()
    }

    deinit {
        task?.cancel()
    }
}
