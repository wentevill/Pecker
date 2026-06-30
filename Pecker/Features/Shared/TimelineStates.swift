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
                name: "\u{65e5}\u{5386}",
                enabled: settings.calendarEnabled,
                status: authorization.calendar
            ),
            noticeSource(
                name: "\u{63d0}\u{9192}\u{4e8b}\u{9879}",
                enabled: settings.remindersEnabled,
                status: authorization.reminders
            )
        ]
        .compactMap { $0 }

        guard !unavailableSources.isEmpty, unavailableSources.count < 2 else {
            return nil
        }

        let bodyText = "\u{5df2}\u{663e}\u{793a}\u{53ef}\u{8bbf}\u{95ee}\u{7684}\u{5185}\u{5bb9}。\u{8981}\u{6062}\u{590d}\u{5168}\u{90e8}\u{65f6}\u{95f4}\u{7ebf}，\u{8bf7}\u{5728}\u{7cfb}\u{7edf}\u{8bbe}\u{7f6e}\u{4e2d}\u{91cd}\u{65b0}\u{6388}\u{6743}\(unavailableSources.joined(separator: "\u{548c}"))。"
        return TimelineAuthorizationNotice(
            titleText: "\u{90e8}\u{5206}\u{6743}\u{9650}\u{53d7}\u{9650}",
            bodyText: bodyText,
            buttonText: "\u{53bb}\u{7cfb}\u{7edf}\u{8bbe}\u{7f6e}",
            accessibilityLabel: "\u{90e8}\u{5206}\u{6743}\u{9650}\u{53d7}\u{9650}，\(bodyText)"
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
