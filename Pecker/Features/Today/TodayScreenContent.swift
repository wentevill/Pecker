import Foundation
import PeckerCore

struct RecognitionIssuePresentation: Equatable {
    let reason: String
    let technicalDetails: String?
}

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

    struct SourceNotice: Equatable {
        let titleText: String
        let bodyText: String
        let buttonText: String
        let accessibilityLabel: String
    }

    enum ImageRecognitionPhase: Equatable {
        case idle
        case recognizing
        case awaitingConfirmation(ImageRecognitionDraft)
        case saving(ImageRecognitionDraft)
        case success(String)
        case failure(RecognitionIssuePresentation)
        case saveFailure(ImageRecognitionDraft, String)
    }

    struct RecognitionPreview: Equatable {
        let titleText: String
        let subtitleText: String?
        let fields: [EventTemplatePresentation.Field]
        let saveButtonText: String
        let cancelButtonText: String
        let buttonsDisabled: Bool
        let errorText: String?
    }

    struct RecognitionActions: Equatable {
        let statusText: String
        let isLoading: Bool
        let buttonsDisabled: Bool
        let errorText: String?
        let errorTechnicalDetails: String?
        let showsTypingIndicator: Bool
        let preview: RecognitionPreview?
    }

    struct Stale: Equatable {
        let bannerText: String
        let retryText: String
    }

    enum Mode: Equatable {
        case loading
        case empty(SourceNotice?)
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
    let sourceNotice: SourceNotice?

    static func recognitionActions(
        settings: TimelineSettings,
        phase: ImageRecognitionPhase
    ) -> RecognitionActions? {
        guard imageRecognitionIsEnabled(settings) else {
            return nil
        }

        switch phase {
        case .idle:
            return RecognitionActions(
                statusText: "\u{7b49}\u{5f85}\u{56fe}\u{7247}",
                isLoading: false,
                buttonsDisabled: false,
                errorText: nil,
                errorTechnicalDetails: nil,
                showsTypingIndicator: false,
                preview: nil
            )
        case .recognizing:
            return RecognitionActions(
                statusText: "\u{6b63}\u{5728}\u{8bc6}\u{522b}",
                isLoading: true,
                buttonsDisabled: true,
                errorText: nil,
                errorTechnicalDetails: nil,
                showsTypingIndicator: true,
                preview: nil
            )
        case let .awaitingConfirmation(draft):
            return RecognitionActions(
                statusText: "\u{8bc6}\u{522b}\u{5b8c}\u{6210}，\u{786e}\u{8ba4}\u{540e}\u{4fdd}\u{5b58}",
                isLoading: false,
                buttonsDisabled: true,
                errorText: nil,
                errorTechnicalDetails: nil,
                showsTypingIndicator: false,
                preview: recognitionPreview(from: draft)
            )
        case let .saving(draft):
            return RecognitionActions(
                statusText: "\u{6b63}\u{5728}\u{4fdd}\u{5b58}",
                isLoading: true,
                buttonsDisabled: true,
                errorText: nil,
                errorTechnicalDetails: nil,
                showsTypingIndicator: false,
                preview: recognitionPreview(
                    from: draft,
                    buttonsDisabled: true
                )
            )
        case let .success(statusText):
            return RecognitionActions(
                statusText: statusText,
                isLoading: false,
                buttonsDisabled: false,
                errorText: nil,
                errorTechnicalDetails: nil,
                showsTypingIndicator: false,
                preview: nil
            )
        case let .failure(issue):
            return RecognitionActions(
                statusText: "\u{8bc6}\u{522b}\u{5931}\u{8d25}",
                isLoading: false,
                buttonsDisabled: false,
                errorText: issue.reason,
                errorTechnicalDetails: issue.technicalDetails,
                showsTypingIndicator: false,
                preview: nil
            )
        case let .saveFailure(draft, errorText):
            return RecognitionActions(
                statusText: "\u{4fdd}\u{5b58}\u{5931}\u{8d25}",
                isLoading: false,
                buttonsDisabled: true,
                errorText: nil,
                errorTechnicalDetails: nil,
                showsTypingIndicator: false,
                preview: recognitionPreview(
                    from: draft,
                    errorText: errorText
                )
            )
        }
    }

    private static func recognitionPreview(
        from draft: ImageRecognitionDraft,
        buttonsDisabled: Bool = false,
        errorText: String? = nil
    ) -> RecognitionPreview {
        let presentation = draft.template.presentation
        let dateStyle = Date.FormatStyle(
            date: .abbreviated,
            time: .shortened
        )
        let timingText: String
        if let endDate = draft.endDate {
            timingText = "\(draft.startDate.formatted(dateStyle)) – \(endDate.formatted(dateStyle))"
        } else {
            timingText = draft.startDate.formatted(dateStyle)
        }
        let fields = [
            EventTemplatePresentation.Field(
                label: "\u{65f6}\u{95f4}",
                value: timingText
            )
        ] + presentation.fields
        return RecognitionPreview(
            titleText: presentation.title,
            subtitleText: presentation.subtitle,
            fields: fields,
            saveButtonText: "\u{4fdd}\u{5b58}",
            cancelButtonText: "\u{53d6}\u{6d88}",
            buttonsDisabled: buttonsDisabled,
            errorText: errorText
        )
    }

    private static func imageRecognitionIsEnabled(
        _ settings: TimelineSettings
    ) -> Bool {
        switch settings.aiRecognitionMode {
        case .off:
            return false
        case .openAI:
            return settings.openAIAPIKeyConfigured
        }
    }

    static func make(
        from state: TimelineScreenState,
        now: Date,
        authorization: SourceAuthorization? = nil,
        settings: TimelineSettings = .init(),
        locale: Locale = .autoupdatingCurrent,
        calendar: Calendar = .autoupdatingCurrent
    ) -> TodayScreenContent {
        let dateText = Self.headerDateText(now, locale: locale, calendar: calendar)
        let header = Header(
            dateText: dateText,
            todayText: "Today",
            settingsButtonLabel: "\u{8bbe}\u{7f6e}",
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
                stale: nil,
                sourceNotice: nil
            )
        case let .empty(notice):
            let sourceNotice = notice.map { mappedNotice(from: $0) }
            return TodayScreenContent(
                header: header,
                mode: .empty(sourceNotice),
                nowCard: nil,
                nextCard: nil,
                pinnedCard: nil,
                summary: fullTimelineSummary(),
                footer: nil,
                permission: nil,
                failure: nil,
                stale: nil,
                sourceNotice: sourceNotice
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
                stale: nil,
                sourceNotice: nil
            )
        case let .stale(snapshot, message):
            let timeline = Self.timelineContent(
                snapshot: snapshot,
                now: now,
                authorization: authorization,
                settings: settings,
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
                ),
                sourceNotice: timeline.sourceNotice
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
                stale: nil,
                sourceNotice: nil
            )
        case let .content(snapshot):
            let timeline = Self.timelineContent(
                snapshot: snapshot,
                now: now,
                authorization: authorization,
                settings: settings,
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
                stale: nil,
                sourceNotice: timeline.sourceNotice
                )
        }
    }

    private static func mappedNotice(from notice: TimelineAuthorizationNotice) -> SourceNotice {
        SourceNotice(
            titleText: notice.titleText,
            bodyText: notice.bodyText,
            buttonText: notice.buttonText,
            accessibilityLabel: notice.accessibilityLabel
        )
    }

    private struct TimelineContent {
        let nowCard: Card?
        let nextCard: Card?
        let pinnedCard: Card?
        let summary: Summary?
        let footer: Footer?
        let sourceNotice: SourceNotice?
    }

    private static func timelineContent(
        snapshot: TodaySnapshot,
        now: Date,
        authorization: SourceAuthorization?,
        settings: TimelineSettings,
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
                makePinnedCard(
                    $0,
                    now: now,
                    locale: locale,
                    calendar: calendar,
                    pinOrigin: snapshot.pinOrigin
                )
            },
            summary: {
                let count = TodayPresentation.summaryCount(
                    for: snapshot,
                    now: now
                )
                return Summary(
                    titleText: "\u{4eca}\u{5929}\u{8fd8}\u{6709} \(count) \u{4e2a}\u{65e5}\u{7a0b}",
                    accessibilityLabel: "\u{4eca}\u{5929}\u{8fd8}\u{6709} \(count) \u{4e2a}\u{65e5}\u{7a0b}，\u{6253}\u{5f00}\u{5b8c}\u{6574}\u{65f6}\u{95f4}\u{7ebf}"
                )
            }(),
            footer: Footer(
                generatedAtText: generatedAtText(snapshot.generatedAt, now: now, locale: locale)
            ),
            sourceNotice: sourceNotice(
                authorization: authorization,
                settings: settings
            )
        )
    }

    private static func fullTimelineSummary() -> Summary {
        Summary(
            titleText: "\u{67e5}\u{770b}\u{5b8c}\u{6574}\u{65f6}\u{95f4}\u{7ebf}",
            accessibilityLabel: "\u{6253}\u{5f00}\u{5b8c}\u{6574}\u{65f6}\u{95f4}\u{7ebf}，\u{67e5}\u{770b}\u{5386}\u{53f2}\u{548c}\u{672a}\u{6765}\u{65e5}\u{7a0b}"
        )
    }

    private static func sourceNotice(
        authorization: SourceAuthorization?,
        settings: TimelineSettings
    ) -> SourceNotice? {
        guard let notice = TimelineAuthorizationNotice.make(
            authorization: authorization,
            settings: settings
        ) else {
            return nil
        }

        return SourceNotice(
            titleText: notice.titleText,
            bodyText: notice.bodyText,
            buttonText: notice.buttonText,
            accessibilityLabel: notice.accessibilityLabel
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
            until: countdownTargetDate(for: item, now: now) ?? now,
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
            statusText: "\u{73b0}\u{5728}",
            badgeText: nil,
            titleText: item.title,
            timeText: timeText,
            secondaryText: "\u{5269}\u{4f59} \(remainingText)",
            tertiaryText: concurrentText,
            progressText: progressText
        )

        return Card(
            id: item.id,
            kind: .now,
            accent: .now,
            statusText: "\u{73b0}\u{5728}",
            badgeText: nil,
            symbolName: symbolName(for: item, fallback: .now),
            titleText: item.title,
            timeText: timeText,
            secondaryText: "\u{5269}\u{4f59} \(remainingText)",
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
            statusText: "\u{4e0b}\u{4e00}\u{9879}",
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
            statusText: "\u{4e0b}\u{4e00}\u{9879}",
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
        calendar: Calendar,
        pinOrigin: PinOrigin?
    ) -> Card {
        let badgeText = TodayPresentation.pinBadgeText(for: pinOrigin)
        let timeText = pinnedTimeText(
            for: item,
            now: now,
            locale: locale,
            calendar: calendar,
            includeLocation: true
        )
        let countdown = relativeCountdownText(
            target: countdownTargetDate(for: item, now: now),
            now: now
        )
        let accessibilityLabel = accessibilityLabel(
            statusText: "\u{56fa}\u{5b9a}\u{884c}\u{7a0b}",
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
            statusText: "\u{56fa}\u{5b9a}\u{884c}\u{7a0b}",
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
        now: Date,
        locale: Locale,
        calendar: Calendar,
        includeLocation: Bool
    ) -> String {
        var style = calendar.isDate(item.startDate, inSameDayAs: now)
            ? Date.FormatStyle()
                .hour(.defaultDigits(amPM: .omitted))
                .minute()
                .locale(locale)
            : Date.FormatStyle()
                .month()
                .day()
                .hour(.defaultDigits(amPM: .omitted))
                .minute()
                .locale(locale)
        style.calendar = calendar
        style.timeZone = calendar.timeZone
        let startText = item.startDate.formatted(style)

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
            "\u{8d77}\u{98de}"
        case .train:
            "\u{53d1}\u{8f66}"
        case .interview:
            "\u{9762}\u{8bd5}"
        case .meeting:
            "\u{4f1a}\u{8bae}"
        case .deadline:
            "\u{622a}\u{6b62}"
        case .task:
            "\u{5f85}\u{529e}"
        case .travel, .unknown:
            nil
        }
    }

    private static func relativeCountdownText(
        start: Date,
        now: Date
    ) -> String {
        relativeCountdownText(target: start, now: now)
    }

    private static func relativeCountdownText(
        target: Date?,
        now: Date
    ) -> String {
        guard let target else {
            return ""
        }

        let interval = max(0, target.timeIntervalSince(now))
        return "\u{8fd8}\u{6709} \(durationText(for: interval))"
    }

    private static func countdownTargetDate(
        for item: TimelineItem,
        now: Date
    ) -> Date? {
        if let endDate = item.endDate,
           item.startDate <= now,
           endDate > now
        {
            return endDate
        }

        if item.startDate > now {
            return item.startDate
        }

        return nil
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
            return "\u{4e0d}\u{5230} 1 \u{5206}\u{949f}"
        }

        let totalMinutes = Int((interval / 60).rounded(.down))
        let hours = totalMinutes / 60
        let minutes = totalMinutes % 60

        switch (hours, minutes) {
        case let (hours, 0) where hours > 0:
            return "\(hours) \u{5c0f}\u{65f6}"
        case let (0, minutes):
            return "\(minutes) \u{5206}\u{949f}"
        case let (hours, minutes):
            return "\(hours) \u{5c0f}\u{65f6} \(minutes) \u{5206}\u{949f}"
        }
    }

    private static func generatedAtText(
        _ date: Date,
        now: Date,
        locale: Locale
    ) -> String {
        let interval = abs(date.timeIntervalSince(now))
        if interval < 60 {
            return "\u{521a}\u{521a}\u{66f4}\u{65b0}"
        }

        let style = Date.FormatStyle()
            .hour(.defaultDigits(amPM: .omitted))
            .minute()
            .locale(locale)
        return "\u{66f4}\u{65b0}\u{4e8e} \(date.formatted(style))"
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
            parts.append("\u{8fdb}\u{5ea6} \(progressText)")
        }
        return parts.joined(separator: "，")
    }

    private static func permissionBodyText(
        for authorization: SourceAuthorization
    ) -> String {
        let missing: [String] = [
            authorization.calendar == .fullAccess ? nil : "\u{65e5}\u{5386}",
            authorization.reminders == .fullAccess ? nil : "\u{63d0}\u{9192}\u{4e8b}\u{9879}"
        ]
        .compactMap { $0 }

        guard !missing.isEmpty else {
            return "\u{5f00}\u{542f}\u{540e}，Today \u{624d}\u{80fd}\u{663e}\u{793a}\u{4f60}\u{7684}\u{65e5}\u{7a0b}。"
        }

        return "\u{5141}\u{8bb8}\u{8bbf}\u{95ee}\(missing.joined(separator: "\u{548c}"))\u{540e}，Today \u{624d}\u{80fd}\u{66f4}\u{65b0}\u{65f6}\u{95f4}\u{7ebf}。"
    }
}
