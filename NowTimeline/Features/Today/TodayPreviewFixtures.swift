import SwiftUI
import NowTimelineCore

enum TodayPreviewFixtures {
    static func defaultContent() -> TodayScreenContent {
        content(
            snapshot: snapshot(
                generatedAt: sampleNow,
                nowItemID: "now",
                concurrentNowCount: 1,
                nextItemID: "next",
                pinnedItemID: "pinned",
                pinOrigin: .automatic,
                items: [
                    item(
                        id: "now",
                        title: "Daily Standup",
                        start: sampleNow.addingTimeInterval(-18 * 60),
                        end: sampleNow.addingTimeInterval(12 * 60),
                        source: .calendar,
                        kind: .meeting
                    ),
                    item(
                        id: "shadow",
                        title: "Shadow Sync",
                        start: sampleNow.addingTimeInterval(-7 * 60),
                        end: sampleNow.addingTimeInterval(18 * 60),
                        source: .calendar,
                        kind: .meeting
                    ),
                    item(
                        id: "next",
                        title: "Product Review",
                        start: sampleNow.addingTimeInterval(12 * 60),
                        end: sampleNow.addingTimeInterval(57 * 60),
                        source: .calendar,
                        kind: .meeting
                    ),
                    item(
                        id: "pinned",
                        title: "SQ 833 新加坡航空",
                        start: sampleNow.addingTimeInterval(4 * 3_600 + 47 * 60),
                        end: sampleNow.addingTimeInterval(6 * 3_600),
                        source: .calendar,
                        kind: .flight,
                        location: "T3 航站楼 · Gate B7"
                    )
                ]
            ),
            now: sampleNow
        )
    }

    static func loadingContent() -> TodayScreenContent {
        TodayScreenContent.make(from: .loading, now: sampleNow, locale: zhLocale, calendar: calendar)
    }

    static func concurrentNowContent() -> TodayScreenContent {
        content(
            snapshot: snapshot(
                generatedAt: sampleNow,
                nowItemID: "now",
                concurrentNowCount: 2,
                nextItemID: "next",
                pinnedItemID: "pinned",
                pinOrigin: .manual,
                items: [
                    item(
                        id: "now",
                        title: "Customer Support",
                        start: sampleNow.addingTimeInterval(-20 * 60),
                        end: sampleNow.addingTimeInterval(40 * 60),
                        source: .calendar,
                        kind: .meeting
                    ),
                    item(
                        id: "now-2",
                        title: "Support Ping",
                        start: sampleNow.addingTimeInterval(-10 * 60),
                        end: sampleNow.addingTimeInterval(15 * 60),
                        source: .calendar,
                        kind: .meeting
                    ),
                    item(
                        id: "now-3",
                        title: "Urgent Reminder",
                        start: sampleNow.addingTimeInterval(-5 * 60),
                        end: sampleNow.addingTimeInterval(5 * 60),
                        source: .reminder,
                        kind: .task
                    ),
                    item(
                        id: "next",
                        title: "Design Review",
                        start: sampleNow.addingTimeInterval(25 * 60),
                        end: sampleNow.addingTimeInterval(70 * 60),
                        source: .calendar,
                        kind: .meeting
                    ),
                    item(
                        id: "pinned",
                        title: "Train D301",
                        start: sampleNow.addingTimeInterval(3 * 3_600),
                        end: sampleNow.addingTimeInterval(4 * 3_600),
                        source: .calendar,
                        kind: .train,
                        location: "Shanghai Station"
                    )
                ]
            ),
            now: sampleNow
        )
    }

    static func longTitleContent() -> TodayScreenContent {
        content(
            snapshot: snapshot(
                generatedAt: sampleNow,
                nowItemID: "now",
                concurrentNowCount: 0,
                nextItemID: "next",
                pinnedItemID: "pinned",
                pinOrigin: .automatic,
                items: [
                    item(
                        id: "now",
                        title: "This is a deliberately long event title that should wrap across multiple lines without truncation",
                        start: sampleNow.addingTimeInterval(-8 * 60),
                        end: sampleNow.addingTimeInterval(14 * 60),
                        source: .calendar,
                        kind: .meeting
                    ),
                    item(
                        id: "next",
                        title: "Another very long upcoming item title that keeps going to stress multiline layout",
                        start: sampleNow.addingTimeInterval(25 * 60),
                        end: sampleNow.addingTimeInterval(70 * 60),
                        source: .calendar,
                        kind: .meeting
                    ),
                    item(
                        id: "pinned",
                        title: "Pinned item with a long descriptive title and a location that should stay readable",
                        start: sampleNow.addingTimeInterval(4 * 3_600 + 10 * 60),
                        end: sampleNow.addingTimeInterval(5 * 3_600),
                        source: .calendar,
                        kind: .flight,
                        location: "Terminal 3 · Gate B7"
                    )
                ]
            ),
            now: Date(timeIntervalSince1970: 1_800_000_000)
        )
    }

    static func emptyContent() -> TodayScreenContent {
        TodayScreenContent.make(from: .empty, now: sampleNow, locale: zhLocale, calendar: calendar)
    }

    static func staleContent() -> TodayScreenContent {
        TodayScreenContent.make(
            from: .stale(
                snapshot(
                    generatedAt: sampleNow.addingTimeInterval(-3_600),
                    nowItemID: "now",
                    concurrentNowCount: 0,
                    nextItemID: "next",
                    pinnedItemID: "pinned",
                    pinOrigin: .automatic,
                    items: [
                        item(
                        id: "now",
                        title: "Daily Standup",
                        start: sampleNow.addingTimeInterval(-18 * 60),
                        end: sampleNow.addingTimeInterval(12 * 60),
                            source: .calendar,
                            kind: .meeting
                        ),
                        item(
                        id: "next",
                        title: "Product Review",
                        start: sampleNow.addingTimeInterval(12 * 60),
                        end: sampleNow.addingTimeInterval(57 * 60),
                            source: .calendar,
                            kind: .meeting
                        ),
                        item(
                        id: "pinned",
                        title: "SQ 833 新加坡航空",
                        start: sampleNow.addingTimeInterval(4 * 3_600 + 47 * 60),
                        end: sampleNow.addingTimeInterval(6 * 3_600),
                            source: .calendar,
                            kind: .flight,
                            location: "T3 航站楼 · Gate B7"
                        )
                    ]
                ),
                "数据可能已过时"
            ),
            now: sampleNow,
            locale: zhLocale,
            calendar: calendar
        )
    }

    static func partialPermissionContent() -> TodayScreenContent {
        TodayScreenContent.make(
            from: .permissionRequired(
                .init(
                    calendar: .denied,
                    reminders: .fullAccess
                )
            ),
            now: sampleNow,
            locale: zhLocale,
            calendar: calendar
        )
    }

    static func failureContent() -> TodayScreenContent {
        TodayScreenContent.make(
            from: .failure("Unable to refresh timeline."),
            now: sampleNow,
            locale: zhLocale,
            calendar: calendar
        )
    }

    private static var sampleNow: Date {
        sampleDate()
    }

    private static var zhLocale: Locale {
        Locale(identifier: "zh_CN")
    }

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = zhLocale
        calendar.timeZone = .init(secondsFromGMT: 8 * 3_600) ?? .current
        return calendar
    }

    private static func content(
        snapshot: TodaySnapshot,
        now: Date
    ) -> TodayScreenContent {
        TodayScreenContent.make(
            from: .content(snapshot),
            now: now,
            locale: zhLocale,
            calendar: calendar
        )
    }

    private static func snapshot(
        generatedAt: Date,
        nowItemID: String?,
        concurrentNowCount: Int,
        nextItemID: String?,
        pinnedItemID: String?,
        pinOrigin: PinOrigin?,
        items: [TimelineItem]
    ) -> TodaySnapshot {
        TodaySnapshot(
            schemaVersion: TodaySnapshot.currentSchemaVersion,
            generatedAt: generatedAt,
            staleAfter: generatedAt.addingTimeInterval(30 * 60),
            items: items,
            nowItemID: nowItemID,
            concurrentNowCount: concurrentNowCount,
            nextItemID: nextItemID,
            pinnedItemID: pinnedItemID,
            pinOrigin: pinOrigin
        )
    }

    private static func item(
        id: String,
        title: String,
        start: Date,
        end: Date,
        source: TimelineSource,
        kind: TimelineKind,
        location: String? = nil,
        isAllDay: Bool = false
    ) -> TimelineItem {
        TimelineItem(
            id: id,
            sourceIdentifier: id,
            title: title,
            startDate: start,
            endDate: end,
            isAllDay: isAllDay,
            source: source,
            kind: kind,
            location: location,
            notes: nil
        )
    }

    private static func sampleDate() -> Date {
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = 2025
        components.month = 5
        components.day = 20
        components.hour = 9
        components.minute = 48
        return components.date ?? Date(timeIntervalSince1970: 1_800_000_000)
    }
}

@MainActor
struct TodayPreviewHost: View {
    var body: some View {
        TodayScreen(
            content: TodayPreviewFixtures.defaultContent(),
            refreshAction: {},
            onOpenSettings: {},
            onOpenCard: { _ in },
            onOpenSummary: {},
            onRetry: {}
        )
    }
}

#if DEBUG
#Preview("Loading") {
    TodayScreen(
        content: TodayPreviewFixtures.loadingContent(),
        refreshAction: {},
        onOpenSettings: {},
        onOpenCard: { _ in },
        onOpenSummary: {},
        onRetry: {}
    )
}

#Preview("Default") {
    TodayScreen(
        content: TodayPreviewFixtures.defaultContent(),
        refreshAction: {},
        onOpenSettings: {},
        onOpenCard: { _ in },
        onOpenSummary: {},
        onRetry: {}
    )
}

#Preview("Concurrent now") {
    TodayScreen(
        content: TodayPreviewFixtures.concurrentNowContent(),
        refreshAction: {},
        onOpenSettings: {},
        onOpenCard: { _ in },
        onOpenSummary: {},
        onRetry: {}
    )
}

#Preview("Long titles") {
    TodayScreen(
        content: TodayPreviewFixtures.longTitleContent(),
        refreshAction: {},
        onOpenSettings: {},
        onOpenCard: { _ in },
        onOpenSummary: {},
        onRetry: {}
    )
    .dynamicTypeSize(.xxLarge)
}

#Preview("Empty") {
    TodayScreen(
        content: TodayPreviewFixtures.emptyContent(),
        refreshAction: {},
        onOpenSettings: {},
        onOpenCard: { _ in },
        onOpenSummary: {},
        onRetry: {}
    )
}

#Preview("Stale") {
    TodayScreen(
        content: TodayPreviewFixtures.staleContent(),
        refreshAction: {},
        onOpenSettings: {},
        onOpenCard: { _ in },
        onOpenSummary: {},
        onRetry: {}
    )
}

#Preview("Permission") {
    TodayScreen(
        content: TodayPreviewFixtures.partialPermissionContent(),
        refreshAction: {},
        onOpenSettings: {},
        onOpenCard: { _ in },
        onOpenSummary: {},
        onRetry: {}
    )
}

#Preview("Failure") {
    TodayScreen(
        content: TodayPreviewFixtures.failureContent(),
        refreshAction: {},
        onOpenSettings: {},
        onOpenCard: { _ in },
        onOpenSummary: {},
        onRetry: {}
    )
}

#Preview("Reduce transparency") {
    TodayScreen(
        content: TodayPreviewFixtures.defaultContent(),
        refreshAction: {},
        onOpenSettings: {},
        onOpenCard: { _ in },
        onOpenSummary: {},
        onRetry: {}
    )
    .environment(\.timelineReduceTransparencyOverride, true)
}
#endif
