import Foundation
import PeckerCore

struct ActivityCoordinator: Sendable {
    private let client: any ActivityClient
    private let calendar: Calendar
    private let presentationAdapter: LiveActivityPresentationAdapter

    init(
        client: any ActivityClient,
        calendar: Calendar = .current,
        presentationAdapter: LiveActivityPresentationAdapter = .init()
    ) {
        self.client = client
        self.calendar = calendar
        self.presentationAdapter = presentationAdapter
    }

    @discardableResult
    func reconcile(
        snapshot: TodaySnapshot,
        settings: TimelineSettings,
        now: Date
    ) async throws -> ActivityDecision {
        try await reconcileWithBoundary(
            snapshot: snapshot,
            settings: settings,
            now: now
        ).decision
    }

    func reconcileWithBoundary(
        snapshot: TodaySnapshot,
        settings: TimelineSettings,
        now: Date
    ) async throws -> ActivityReconciliationResult {
        let attributes = PeckerActivityAttributes(
            localDayIdentifier: localDayIdentifier(for: now)
        )
        let activitySnapshots = await client.activitySnapshots()
        let staleSnapshots = activitySnapshots
            .filter { $0.localDayIdentifier != attributes.localDayIdentifier }
            .sorted { $0.id < $1.id }
        let currentDaySnapshots = activitySnapshots
            .filter { $0.localDayIdentifier == attributes.localDayIdentifier }
            .sorted { $0.id < $1.id }
        let currentDaySnapshot = currentDaySnapshots.first
        let duplicateSnapshots = Array(currentDaySnapshots.dropFirst())
        let decision = decision(
            snapshot: snapshot,
            settings: settings,
            now: now,
            currentDaySnapshot: currentDaySnapshot
        )
        let nextBoundary = settings.liveActivityEnabled
            ? desiredState(snapshot: snapshot, now: now).map {
                staleDate(for: $0, snapshot: snapshot, now: now)
            }
            : nil

        if case .end = decision {
            for snapshot in staleSnapshots + currentDaySnapshots {
                await client.end(id: snapshot.id)
            }
            return ActivityReconciliationResult(
                decision: decision,
                nextBoundary: nil
            )
        }

        for snapshot in staleSnapshots + duplicateSnapshots {
            await client.end(id: snapshot.id)
        }

        switch decision {
        case .none, .end:
            break
        case let .start(state, staleDate):
            try await client.start(
                state: state,
                staleDate: staleDate,
                attributes: attributes
            )
        case let .update(state, staleDate):
            if let currentDaySnapshot {
                await client.update(
                    id: currentDaySnapshot.id,
                    state: state,
                    staleDate: staleDate
                )
            }
        }
        return ActivityReconciliationResult(
            decision: decision,
            nextBoundary: nextBoundary
        )
    }

    private func decision(
        snapshot: TodaySnapshot,
        settings: TimelineSettings,
        now: Date,
        currentDaySnapshot: ActivityClientSnapshot?
    ) -> ActivityDecision {
        guard settings.liveActivityEnabled else {
            return .end
        }

        guard let state = desiredState(snapshot: snapshot, now: now) else {
            return .end
        }

        let staleDate = staleDate(for: state, snapshot: snapshot, now: now)
        guard let currentState = currentDaySnapshot?.contentState else {
            return .start(state, staleDate)
        }

        if currentState == state {
            return .none
        }

        return .update(state, staleDate)
    }

    private func desiredState(
        snapshot: TodaySnapshot,
        now: Date
    ) -> PeckerActivityAttributes.ContentState? {
        guard let primary = primaryItem(snapshot: snapshot, now: now) else {
            return nil
        }

        return presentationAdapter.makeState(
            item: primary,
            status: primaryStatus(
                snapshot: snapshot,
                primary: primary
            ),
            generatedAt: snapshot.generatedAt,
        )
    }

    private func primaryItem(
        snapshot: TodaySnapshot,
        now: Date
    ) -> TimelineItem? {
        if let nowItem = snapshot.resolvedNowItem {
            return nowItem
        }

        if let nextItem = snapshot.resolvedNextItem {
            return nextItem
        }

        if let pinnedItem = snapshot.resolvedPinnedItem,
           isUnfinished(pinnedItem, now: now)
        {
            return pinnedItem
        }

        return nil
    }

    private func primaryStatus(
        snapshot: TodaySnapshot,
        primary: TimelineItem
    ) -> PeckerLiveActivityStatus {
        if primary.id == snapshot.nowItemID {
            return .now
        }
        if primary.id == snapshot.nextItemID {
            return .next
        }
        return .pinned
    }

    private func isUnfinished(_ item: TimelineItem, now: Date) -> Bool {
        if let endDate = item.endDate {
            return endDate > now
        }

        return item.startDate >= now
    }

    private func staleDate(
        for state: PeckerActivityAttributes.ContentState,
        snapshot: TodaySnapshot,
        now: Date
    ) -> Date {
        let candidates = [
            state.countdownTargetDate(at: now),
            snapshot.resolvedNextItem?.startDate,
            snapshot.resolvedPinnedItem?.startDate,
            snapshot.resolvedPinnedItem?.endDate,
            snapshot.staleAfter
        ]
        .compactMap { $0 }
        .filter { $0 > now }

        return candidates.min() ?? snapshot.staleAfter
    }

    private func localDayIdentifier(for date: Date) -> String {
        let components = calendar.dateComponents(
            [.year, .month, .day],
            from: date
        )
        let year = components.year ?? 0
        let month = components.month ?? 0
        let day = components.day ?? 0

        return String(format: "%04d-%02d-%02d", year, month, day)
    }
}
