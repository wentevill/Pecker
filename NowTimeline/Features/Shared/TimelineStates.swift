import NowTimelineCore

enum TimelineScreenState: Equatable {
    case loading
    case content(TodaySnapshot)
    case empty(TimelineAuthorizationNotice?)
    case permissionRequired(SourceAuthorization)
    case stale(TodaySnapshot, String)
    case failure(String)
}

struct TimelineAuthorizationNotice: Equatable {
    let titleText: String
    let bodyText: String
    let buttonText: String
    let accessibilityLabel: String

    static func make(
        authorization: SourceAuthorization?,
        settings: TimelineSettings
    ) -> TimelineAuthorizationNotice? {
        guard let authorization else {
            return nil
        }

        let unavailableSources = [
            noticeSource(
                name: "日历",
                enabled: settings.calendarEnabled,
                status: authorization.calendar
            ),
            noticeSource(
                name: "提醒事项",
                enabled: settings.remindersEnabled,
                status: authorization.reminders
            )
        ]
        .compactMap { $0 }

        guard !unavailableSources.isEmpty, unavailableSources.count < 2 else {
            return nil
        }

        let bodyText = "已显示可访问的内容。要恢复全部时间线，请在系统设置中重新授权\(unavailableSources.joined(separator: "和"))。"
        return TimelineAuthorizationNotice(
            titleText: "部分权限受限",
            bodyText: bodyText,
            buttonText: "去系统设置",
            accessibilityLabel: "部分权限受限，\(bodyText)"
        )
    }

    private static func noticeSource(
        name: String,
        enabled: Bool,
        status: SourceAuthorizationStatus
    ) -> String? {
        guard enabled, status != .fullAccess else {
            return nil
        }
        return name
    }
}

extension TimelineScreenState {
    var snapshot: TodaySnapshot? {
        switch self {
        case let .content(snapshot):
            snapshot
        case let .stale(snapshot, _):
            snapshot
        case .loading, .empty(_), .permissionRequired, .failure:
            nil
        }
    }
}
