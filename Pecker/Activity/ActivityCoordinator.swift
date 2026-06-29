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

        if case .end = decision {
            for snapshot in staleSnapshots + currentDaySnapshots {
                await client.end(id: snapshot.id)
            }
            return decision
        }

        for snapshot in staleSnapshots + duplicateSnapshots {
            await client.end(id: snapshot.id)
        }

        switch decision {
        case .none, .end:
            return decision
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
        return decision
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
            generatedAt: snapshot.generatedAt,
            primaryStatusRawValue: primaryStatus(
                snapshot: snapshot,
                primary: primary
            )
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
        if case let .trainTicket(ticket) = item.template {
            let route = [
                ticket.departureStation,
                ticket.arrivalStation
            ]
                .compactMap { $0 }
                .joined(separator: " → ")
            let seat = [
                ticket.carriageNumber.map { "\($0)车" },
                ticket.seatNumber,
                ticket.checkInGate.map { "\($0)检票" }
            ]
                .compactMap { $0 }
                .joined(separator: " · ")
            return firstNonEmpty(
                [route, seat].filter { !$0.isEmpty }.joined(separator: " · "),
                item.location,
                item.notes
            )
        }
        return firstNonEmpty(item.location, item.notes)
    }

    private func primaryStatus(
        snapshot: TodaySnapshot,
        primary: TimelineItem
    ) -> String {
        if primary.id == snapshot.nowItemID {
            return "now"
        }
        if primary.id == snapshot.nextItemID {
            return "next"
        }
        return "pinned"
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
            state.countdownTargetDate(at: now),
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
