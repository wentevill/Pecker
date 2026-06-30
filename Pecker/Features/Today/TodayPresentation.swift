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

    static func concurrentText(extraCount: Int) -> String? {
        guard extraCount > 0 else {
            return nil
        }

        return "\u{53e6}\u{6709} \(extraCount) \u{9879}\u{8fdb}\u{884c}\u{4e2d}"
    }

    static func pinBadgeText(for origin: PinOrigin?) -> String? {
        switch origin {
        case .automatic:
            "\u{81ea}\u{52a8}\u{63a8}\u{8350}"
        case .manual:
            "\u{624b}\u{52a8}\u{56fa}\u{5b9a}"
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
    static let loadingTitle = "\u{52a0}\u{8f7d}\u{4e2d}"
    static let emptyTitle = "\u{4eca}\u{5929}\u{6682}\u{65f6}\u{7a7a}\u{95f2}"
    static let permissionTitle = "\u{9700}\u{8981}\u{8bbf}\u{95ee}\u{65e5}\u{5386}\u{4e0e}\u{63d0}\u{9192}\u{4e8b}\u{9879}"
    static let permissionButton = "\u{53bb}\u{7cfb}\u{7edf}\u{8bbe}\u{7f6e}"
    static let staleBanner = "\u{6570}\u{636e}\u{53ef}\u{80fd}\u{5df2}\u{8fc7}\u{65f6}"
    static let staleRetry = "\u{91cd}\u{65b0}\u{52a0}\u{8f7d}"
    static let failureTitle = "\u{4eca}\u{5929}\u{6682}\u{65f6}\u{4e0d}\u{53ef}\u{7528}"
    static let failureRetry = "\u{91cd}\u{8bd5}"
}
