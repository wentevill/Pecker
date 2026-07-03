import Foundation
import PeckerCore

enum TodayPresentation {
    static func progress(
        start: Date?,
        end: Date?,
        now: Date
    ) -> Double? {
        guard let start, let end, end > start else {
            return nil
        }

        let duration = end.timeIntervalSince(start)
        guard duration > 0 else {
            return nil
        }

        let elapsed = now.timeIntervalSince(start)
        return min(1, max(0, elapsed / duration))
    }

    static func concurrentText(
        extraCount: Int,
        localizer: AppLocalizer
    ) -> String? {
        guard extraCount > 0 else {
            return nil
        }

        return localizer.string("today.concurrent", extraCount)
    }

    static func pinBadgeText(
        for origin: PinOrigin?,
        localizer: AppLocalizer
    ) -> String? {
        switch origin {
        case .automatic:
            localizer.string("pin.origin.automatic")
        case .manual:
            localizer.string("pin.origin.manual")
        case nil:
            nil
        }
    }

    static func summaryCount(
        for snapshot: TodaySnapshot,
        now: Date
    ) -> Int {
        snapshot.items.filter { item in
            guard !item.isCompleted else {
                return false
            }
            if let endDate = item.endDate {
                return endDate > now
            }
            return item.startDate >= now
        }.count
    }
}

enum TodayStateCopy {
    static func loadingTitle(_ localizer: AppLocalizer) -> String {
        localizer.string("today.loading.title")
    }

    static func emptyTitle(_ localizer: AppLocalizer) -> String {
        localizer.string("today.empty.title")
    }

    static func permissionTitle(_ localizer: AppLocalizer) -> String {
        localizer.string("today.permission.title")
    }

    static func permissionButton(_ localizer: AppLocalizer) -> String {
        localizer.string("today.permission.button")
    }

    static func staleBanner(_ localizer: AppLocalizer) -> String {
        localizer.string("today.stale.banner")
    }

    static func staleRetry(_ localizer: AppLocalizer) -> String {
        localizer.string("today.stale.retry")
    }

    static func failureTitle(_ localizer: AppLocalizer) -> String {
        localizer.string("today.failure.title")
    }

    static func failureRetry(_ localizer: AppLocalizer) -> String {
        localizer.string("today.failure.retry")
    }
}
