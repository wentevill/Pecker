import Foundation
import NowTimelineCore

struct TodayScreenContent: Equatable {
    struct Header: Equatable {
        let dateText: String
        let todayText: String
        let settingsButtonLabel: String
        let accessibilityLabel: String
    }

    struct Card: Equatable, Hashable, Identifiable {
        enum Kind: Equatable {
            case now
            case next
            case pinned
        }

        let id: String
        let kind: Kind
        let accent: TimelineAccent
        let statusText: String
        let badgeText: String?
        let symbolName: String
        let titleText: String
        let timeText: String
        let secondaryText: String?
        let tertiaryText: String?
        let progress: Double?
        let progressText: String?
        let accessibilityLabel: String
    }

    struct Summary: Equatable {
        let titleText: String
        let accessibilityLabel: String
    }

    struct Footer: Equatable {
        let generatedAtText: String
    }

    struct Permission: Equatable {
        let titleText: String
        let bodyText: String
        let buttonText: String
    }

    struct Failure: Equatable {
        let titleText: String
        let bodyText: String
        let retryText: String
    }

    struct Stale: Equatable {
        let bannerText: String
        let retryText: String
    }

    enum Mode: Equatable {
        case loading
        case empty
        case permission
        case stale
        case failure
        case content
    }

    let header: Header
    let mode: Mode
    let nowCard: Card?
    let nextCard: Card?
    let pinnedCard: Card?
    let summary: Summary?
    let footer: Footer?
    let permission: Permission?
    let failure: Failure?
    let stale: Stale?

    static func make(
        from state: TimelineScreenState,
        now: Date,
        locale: Locale = .autoupdatingCurrent,
        calendar: Calendar = .autoupdatingCurrent
    ) -> TodayScreenContent {
        let dateText = Self.headerDateText(now, locale: locale, calendar: calendar)
        let header = Header(
            dateText: dateText,
            todayText: "Today",
            settingsButtonLabel: "设置",
            accessibilityLabel: "\(dateText)，Today"
        )

        switch state {
        case .loading:
            return TodayScreenContent(
                header: header,
                mode: .loading,
                nowCard: nil,
                nextCard: nil,
                pinnedCard: nil,
                summary: nil,
                footer: nil,
                permission: nil,
                failure: nil,
                stale: nil
            )
        case .empty:
            return TodayScreenContent(
                header: header,
                mode: .empty,
                nowCard: nil,
                nextCard: nil,
                pinnedCard: nil,
                summary: nil,
                footer: nil,
                permission: nil,
                failure: nil,
                stale: nil
            )
        case let .permissionRequired(authorization):
            return TodayScreenContent(
                header: header,
                mode: .permission,
                nowCard: nil,
                nextCard: nil,
                pinnedCard: nil,
                summary: nil,
                footer: nil,
                permission: Permission(
                    titleText: TodayStateCopy.permissionTitle,
                    bodyText: permissionBodyText(for: authorization),
                    buttonText: TodayStateCopy.permissionButton
                ),
                failure: nil,
                stale: nil
            )
        case let .stale(snapshot, message):
            let timeline = Self.timelineContent(
                snapshot: snapshot,
                now: now,
                locale: locale,
                calendar: calendar
            )
            return TodayScreenContent(
                header: header,
                mode: .stale,
                nowCard: timeline.nowCard,
                nextCard: timeline.nextCard,
                pinnedCard: timeline.pinnedCard,
                summary: timeline.summary,
                footer: timeline.footer,
                permission: nil,
                failure: nil,
                stale: Stale(
                    bannerText: message,
                    retryText: TodayStateCopy.staleRetry
                )
            )
        case let .failure(message):
            return TodayScreenContent(
                header: header,
                mode: .failure,
                nowCard: nil,
                nextCard: nil,
                pinnedCard: nil,
                summary: nil,
                footer: nil,
                permission: nil,
                failure: Failure(
                    titleText: TodayStateCopy.failureTitle,
                    bodyText: message,
                    retryText: TodayStateCopy.failureRetry
                ),
                stale: nil
            )
        case let .content(snapshot):
            let timeline = Self.timelineContent(
                snapshot: snapshot,
                now: now,
                locale: locale,
                calendar: calendar
            )
            return TodayScreenContent(
                header: header,
                mode: .content,
                nowCard: timeline.nowCard,
                nextCard: timeline.nextCard,
                pinnedCard: timeline.pinnedCard,
                summary: timeline.summary,
                footer: timeline.footer,
                permission: nil,
                failure: nil,
                stale: nil
            )
        }
    }

    private struct TimelineContent {
        let nowCard: Card?
        let nextCard: Card?
        let pinnedCard: Card?
        let summary: Summary?
        let footer: Footer?
    }

    private static func timelineContent(
        snapshot: TodaySnapshot,
        now: Date,
        locale: Locale,
        calendar: Calendar
    ) -> TimelineContent {
        let nowItem = snapshot.resolvedNowItem
        let nextItem = snapshot.resolvedNextItem
        let pinnedItem = snapshot.resolvedPinnedItem

        return TimelineContent(
            nowCard: nowItem.map {
                makeNowCard(
                    $0,
                    now: now,
                    locale: locale,
                    concurrentCount: snapshot.concurrentNowCount
                )
            },
            nextCard: nextItem.map {
                makeNextCard($0, now: now, locale: locale)
            },
            pinnedCard: pinnedItem.map {
                makePinnedCard($0, now: now, locale: locale, pinOrigin: snapshot.pinOrigin)
            },
            summary: Summary(
                titleText: "今天还有 \(TodayPresentation.summaryCount(for: snapshot)) 个日程",
                accessibilityLabel: "今天还有 \(TodayPresentation.summaryCount(for: snapshot)) 个日程，打开完整时间线"
            ),
            footer: Footer(
                generatedAtText: generatedAtText(snapshot.generatedAt, now: now, locale: locale)
            )
        )
    }

    private static func makeNowCard(
        _ item: TimelineItem,
        now: Date,
        locale: Locale,
        concurrentCount: Int
    ) -> Card {
        let progress = TodayPresentation.progress(
            start: item.startDate,
            end: item.endDate,
            now: now
        )
        let remainingText = relativeDurationText(
            until: item.endDate ?? now,
            relativeTo: now
        )
        let concurrentText = TodayPresentation.concurrentText(
            extraCount: max(0, concurrentCount)
        )
        let timeText = timeRangeText(
            start: item.startDate,
            end: item.endDate,
            locale: locale
        )
        let progressText = progress.map {
            "\(Int(($0 * 100).rounded()))%"
        }
        let accessibilityLabel = accessibilityLabel(
            statusText: "现在",
            badgeText: nil,
            titleText: item.title,
            timeText: timeText,
            secondaryText: "剩余 \(remainingText)",
            tertiaryText: concurrentText,
            progressText: progressText
        )

        return Card(
            id: item.id,
            kind: .now,
            accent: .now,
            statusText: "现在",
            badgeText: nil,
            symbolName: symbolName(for: item, fallback: .now),
            titleText: item.title,
            timeText: timeText,
            secondaryText: "剩余 \(remainingText)",
            tertiaryText: concurrentText,
            progress: progress,
            progressText: progressText,
            accessibilityLabel: accessibilityLabel
        )
    }

    private static func makeNextCard(
        _ item: TimelineItem,
        now: Date,
        locale: Locale
    ) -> Card {
        let timeText = timeRangeText(
            start: item.startDate,
            end: item.endDate,
            locale: locale
        )
        let countdown = relativeCountdownText(
            start: item.startDate,
            now: now
        )
        let accessibilityLabel = accessibilityLabel(
            statusText: "下一项",
            badgeText: nil,
            titleText: item.title,
            timeText: timeText,
            secondaryText: countdown,
            tertiaryText: nil,
            progressText: nil
        )

        return Card(
            id: item.id,
            kind: .next,
            accent: .next,
            statusText: "下一项",
            badgeText: nil,
            symbolName: symbolName(for: item, fallback: .next),
            titleText: item.title,
            timeText: timeText,
            secondaryText: countdown,
            tertiaryText: nil,
            progress: nil,
            progressText: nil,
            accessibilityLabel: accessibilityLabel
        )
    }

    private static func makePinnedCard(
        _ item: TimelineItem,
        now: Date,
        locale: Locale,
        pinOrigin: PinOrigin?
    ) -> Card {
        let badgeText = TodayPresentation.pinBadgeText(for: pinOrigin)
        let timeText = pinnedTimeText(for: item, locale: locale, includeLocation: true)
        let countdown = relativeCountdownText(
            start: item.startDate,
            now: now
        )
        let accessibilityLabel = accessibilityLabel(
            statusText: "固定行程",
            badgeText: badgeText,
            titleText: item.title,
            timeText: timeText,
            secondaryText: nil,
            tertiaryText: countdown.isEmpty ? nil : countdown,
            progressText: nil
        )

        return Card(
            id: item.id,
            kind: .pinned,
            accent: .pinned,
            statusText: "固定行程",
            badgeText: badgeText,
            symbolName: symbolName(for: item, fallback: .pinned),
            titleText: item.title,
            timeText: timeText,
            secondaryText: nil,
            tertiaryText: countdown,
            progress: nil,
            progressText: nil,
            accessibilityLabel: accessibilityLabel
        )
    }

    private static func headerDateText(
        _ date: Date,
        locale: Locale,
        calendar: Calendar
    ) -> String {
        var style = Date.FormatStyle()
            .month(.wide)
            .day()
            .weekday(.wide)
            .locale(locale)
        style.calendar = calendar
        style.timeZone = calendar.timeZone
        return date.formatted(style)
    }

    private static func timeRangeText(
        start: Date,
        end: Date?,
        locale: Locale
    ) -> String {
        let style = Date.FormatStyle()
            .hour(.defaultDigits(amPM: .omitted))
            .minute()
            .locale(locale)

        guard let end else {
            return start.formatted(style)
        }

        return "\(start.formatted(style)) – \(end.formatted(style))"
    }

    private static func pinnedTimeText(
        for item: TimelineItem,
        locale: Locale,
        includeLocation: Bool
    ) -> String {
        let startText = item.startDate.formatted(
            Date.FormatStyle()
                .hour(.defaultDigits(amPM: .omitted))
                .minute()
                .locale(locale)
        )

        let baseText: String
        if let kind = kindText(for: item.kind) {
            baseText = "\(startText) \(kind)"
        } else {
            baseText = startText
        }

        guard includeLocation, let location = item.location?.trimmingCharacters(in: .whitespacesAndNewlines), !location.isEmpty else {
            return baseText
        }

        return "\(baseText) · \(location)"
    }

    private static func kindText(for kind: TimelineKind) -> String? {
        switch kind {
        case .flight:
            "起飞"
        case .train:
            "发车"
        case .interview:
            "面试"
        case .meeting:
            "会议"
        case .deadline:
            "截止"
        case .task:
            "待办"
        case .travel, .unknown:
            nil
        }
    }

    private static func relativeCountdownText(
        start: Date,
        now: Date
    ) -> String {
        let interval = max(0, start.timeIntervalSince(now))
        return "还有 \(durationText(for: interval))"
    }

    private static func relativeDurationText(
        until target: Date,
        relativeTo now: Date
    ) -> String {
        let interval = max(0, target.timeIntervalSince(now))
        return durationText(for: interval)
    }

    private static func durationText(for interval: TimeInterval) -> String {
        if interval < 60 {
            return "不到 1 分钟"
        }

        let totalMinutes = Int((interval / 60).rounded(.down))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        switch (hours, minutes) {
        case let (hours, 0) where hours > 0:
            return "\(hours) 小时"
        case let (0, minutes):
            return "\(minutes) 分钟"
        case let (hours, minutes):
            return "\(hours) 小时 \(minutes) 分钟"
        }
    }

    private static func generatedAtText(
        _ date: Date,
        now: Date,
        locale: Locale
    ) -> String {
        let interval = abs(date.timeIntervalSince(now))
        if interval < 60 {
            return "刚刚更新"
        }

        let style = Date.FormatStyle()
            .hour(.defaultDigits(amPM: .omitted))
            .minute()
            .locale(locale)
        return "更新于 \(date.formatted(style))"
    }

    private static func symbolName(
        for item: TimelineItem,
        fallback: TodayScreenContent.Card.Kind
    ) -> String {
        switch item.kind {
        case .flight:
            "airplane"
        case .train:
            "train.side.front.car"
        case .interview:
            "person.text.rectangle"
        case .meeting:
            "person.2.fill"
        case .deadline:
            "calendar.badge.exclamationmark"
        case .task:
            "checklist"
        case .travel:
            "suitcase.fill"
        case .unknown:
            switch fallback {
            case .now:
                "clock.fill"
            case .next:
                "calendar"
            case .pinned:
                "pin.fill"
            }
        }
    }

    private static func accessibilityLabel(
        statusText: String,
        badgeText: String?,
        titleText: String,
        timeText: String,
        secondaryText: String?,
        tertiaryText: String?,
        progressText: String?
    ) -> String {
        var parts: [String] = [statusText]
        if let badgeText {
            parts.append(badgeText)
        }
        parts.append(titleText)
        parts.append(timeText)
        if let secondaryText, !secondaryText.isEmpty {
            parts.append(secondaryText)
        }
        if let tertiaryText, !tertiaryText.isEmpty {
            parts.append(tertiaryText)
        }
        if let progressText, !progressText.isEmpty {
            parts.append("进度 \(progressText)")
        }
        return parts.joined(separator: "，")
    }

    private static func permissionBodyText(
        for authorization: SourceAuthorization
    ) -> String {
        let missing: [String] = [
            authorization.calendar == .fullAccess ? nil : "日历",
            authorization.reminders == .fullAccess ? nil : "提醒事项"
        ]
        .compactMap { $0 }

        guard !missing.isEmpty else {
            return "开启后，Today 才能显示你的日程。"
        }

        return "允许访问\(missing.joined(separator: "和"))后，Today 才能更新时间线。"
    }
}
