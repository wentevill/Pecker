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

        return "另有 \(extraCount) 项进行中"
    }

    static func pinBadgeText(for origin: PinOrigin?) -> String? {
        switch origin {
        case .automatic:
            "自动推荐"
        case .manual:
            "手动固定"
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
    static let loadingTitle = "加载中"
    static let emptyTitle = "今天暂时空闲"
    static let permissionTitle = "需要访问日历与提醒事项"
    static let permissionButton = "去系统设置"
    static let staleBanner = "数据可能已过时"
    static let staleRetry = "重新加载"
    static let failureTitle = "今天暂时不可用"
    static let failureRetry = "重试"
}
