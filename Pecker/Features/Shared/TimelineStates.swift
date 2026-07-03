import PeckerCore

enum TimelineScreenState: Equatable {
    case loading
    case content(TodaySnapshot)
    case empty(TimelineAuthorizationNotice?)
    case permissionRequired(SourceAuthorization)
    case stale(TodaySnapshot, String)
    case failure(String)
}

struct TimelineAuthorizationNotice: Equatable {
    let unavailableSources: [TimelineSource]
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

        let unavailableSources: [TimelineSource] = [
            noticeSource(
                source: .calendar,
                enabled: settings.calendarEnabled,
                status: authorization.calendar
            ),
            noticeSource(
                source: .reminder,
                enabled: settings.remindersEnabled,
                status: authorization.reminders
            )
        ]
        .compactMap { $0 }

        guard !unavailableSources.isEmpty, unavailableSources.count < 2 else {
            return nil
        }

        let bodyText = "Available content is visible. Restore access in Settings to show the complete timeline."
        return TimelineAuthorizationNotice(
            unavailableSources: unavailableSources,
            titleText: "Some permissions are limited",
            bodyText: bodyText,
            buttonText: "Open Settings",
            accessibilityLabel: "Some permissions are limited. \(bodyText)"
        )
    }

    private static func noticeSource(
        source: TimelineSource,
        enabled: Bool,
        status: SourceAuthorizationStatus
    ) -> TimelineSource? {
        guard enabled, status != .fullAccess else {
            return nil
        }
        return source
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
