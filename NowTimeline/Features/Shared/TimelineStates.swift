import NowTimelineCore

enum TimelineScreenState: Equatable {
    case loading
    case content(TodaySnapshot)
    case empty
    case permissionRequired(SourceAuthorization)
    case stale(TodaySnapshot, String)
    case failure(String)
}
