#if DEBUG
import SwiftUI
import PeckerCore

enum TodayPreviewFixtures {
    static func makeSampleNow() -> Date {
        sampleDate()
    }

    static func defaultSnapshot() -> TodaySnapshot {
        snapshot(
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
                    title: "SQ 833 \u{65b0}\u{52a0}\u{5761}\u{822a}\u{7a7a}",
                    start: sampleNow.addingTimeInterval(4 * 3_600 + 47 * 60),
                    end: sampleNow.addingTimeInterval(6 * 3_600),
                    source: .calendar,
                    kind: .flight,
                    location: "T3 \u{822a}\u{7ad9}\u{697c} · Gate B7"
                )
            ]
        )
    }

    static func flightItem() -> TimelineItem {
        item(
            id: "flight",
            title: "SQ 833 \u{65b0}\u{52a0}\u{5761}\u{822a}\u{7a7a} · \u{4e0a}\u{6d77}\u{98de}\u{65b0}\u{52a0}\u{5761}",
            start: sampleNow.addingTimeInterval(4 * 3_600 + 47 * 60),
            end: sampleNow.addingTimeInterval(6 * 3_600),
            source: .calendar,
            kind: .flight,
            location: "T3 \u{822a}\u{7ad9}\u{697c} · Gate B7",
            notes: "\u{767b}\u{673a}\u{53e3}\u{53ef}\u{80fd}\u{53d8}\u{66f4}，\u{8bf7}\u{7559}\u{610f}\u{673a}\u{573a}\u{901a}\u{77e5}。\u{6b64}\u{5904}\u{7528}\u{4e8e}\u{9a8c}\u{8bc1}\u{957f}\u{5907}\u{6ce8}\u{5728}\u{8be6}\u{60c5}\u{9875}\u{91cc}\u{7684}\u{6362}\u{884c}\u{4e0e}\u{53ef}\u{8bfb}\u{6027}。"
        )
    }

    static func defaultContent() -> TodayScreenContent {
        content(
            snapshot: defaultSnapshot(),
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
        TodayScreenContent.make(from: .empty(nil), now: sampleNow, locale: zhLocale, calendar: calendar)
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
                        title: "SQ 833 \u{65b0}\u{52a0}\u{5761}\u{822a}\u{7a7a}",
                        start: sampleNow.addingTimeInterval(4 * 3_600 + 47 * 60),
                        end: sampleNow.addingTimeInterval(6 * 3_600),
                            source: .calendar,
                            kind: .flight,
                            location: "T3 \u{822a}\u{7ad9}\u{697c} · Gate B7"
                        )
                    ]
                ),
                "\u{6570}\u{636e}\u{53ef}\u{80fd}\u{5df2}\u{8fc7}\u{65f6}"
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
        notes: String? = nil,
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
            notes: notes
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
            onOpenConcurrentItems: {},
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
        onOpenConcurrentItems: {},
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
        onOpenConcurrentItems: {},
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
        onOpenConcurrentItems: {},
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
        onOpenConcurrentItems: {},
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
        onOpenConcurrentItems: {},
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
        onOpenConcurrentItems: {},
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
        onOpenConcurrentItems: {},
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
        onOpenConcurrentItems: {},
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
        onOpenConcurrentItems: {},
        onOpenSummary: {},
        onRetry: {}
    )
    .environment(\.timelineReduceTransparencyOverride, true)
}
#endif
#endif
