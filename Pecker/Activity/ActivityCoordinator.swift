import Foundation
import PeckerCore

struct ActivityCoordinator: Sendable {
    private let client: any ActivityClient
    private let calendar: Calendar

    init(client: any ActivityClient, calendar: Calendar = .current) {
        self.client = client
        self.calendar = calendar
    }

    @discardableResult
    func reconcile(
        snapshot: TodaySnapshot,
        settings: TimelineSettings,
        now: Date
    ) async throws -> ActivityDecision {
        let attributes = PeckerActivityAttributes(
            localDayIdentifier: localDayIdentifier(for: now)
        )
        let decision = await decision(
            snapshot: snapshot,
            settings: settings,
            now: now
        )

        try await client.apply(decision, attributes: attributes)
        return decision
    }

    private func decision(
        snapshot: TodaySnapshot,
        settings: TimelineSettings,
        now: Date
    ) async -> ActivityDecision {
        guard settings.liveActivityEnabled else {
            return .end
        }

        guard let state = desiredState(snapshot: snapshot, now: now) else {
            return .end
        }

        let staleDate = staleDate(for: state, snapshot: snapshot, now: now)
        guard let currentState = await client.currentState() else {
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

        let next = snapshot.resolvedNextItem
        let pinned = snapshot.resolvedPinnedItem

        return PeckerActivityAttributes.ContentState(
            primaryTitle: primary.title,
            primarySubtitle: subtitle(for: primary),
            primaryStartDate: primary.startDate,
            primaryEndDate: primary.endDate,
            primaryKindRawValue: primary.kind.rawValue,
            primarySourceIdentifier: primary.sourceIdentifier,
            nextTitle: next?.title,
            nextStartDate: next?.startDate,
            pinnedTitle: pinned?.title,
            pinnedSubtitle: pinned.flatMap(subtitle(for:)),
            additionalActiveCount: additionalActiveCount(
                snapshot: snapshot,
                primary: primary
            ),
            generatedAt: snapshot.generatedAt
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

    private func additionalActiveCount(
        snapshot: TodaySnapshot,
        primary: TimelineItem
    ) -> Int {
        guard primary.id == snapshot.nowItemID else {
            return 0
        }

        return snapshot.concurrentNowCount
    }

    private func subtitle(for item: TimelineItem) -> String? {
        firstNonEmpty(item.location, item.notes)
    }

    private func firstNonEmpty(_ values: String?...) -> String? {
        values
            .lazy
            .compactMap { value in
                value?.trimmingCharacters(in: .whitespacesAndNewlines)
            }
            .first { !$0.isEmpty }
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
            state.primaryEndDate,
            state.nextStartDate,
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
