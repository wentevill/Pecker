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
        phase: ImageRecognitionPhase,
        localizer: AppLocalizer = AppLocalizer(language: .system)
    ) -> RecognitionActions? {
        guard imageRecognitionIsEnabled(settings) else {
            return nil
        }

        switch phase {
        case .idle:
            return RecognitionActions(
                statusText: localizer.string("recognition.status.waiting"),
                isLoading: false,
                buttonsDisabled: false,
                errorText: nil,
                errorTechnicalDetails: nil,
                showsTypingIndicator: false,
                preview: nil
            )
        case .recognizing:
            return RecognitionActions(
                statusText: localizer.string("recognition.status.recognizing"),
                isLoading: true,
                buttonsDisabled: true,
                errorText: nil,
                errorTechnicalDetails: nil,
                showsTypingIndicator: true,
                preview: nil
            )
        case let .awaitingConfirmation(draft):
            return RecognitionActions(
                statusText: localizer.string("recognition.status.ready"),
                isLoading: false,
                buttonsDisabled: true,
                errorText: nil,
                errorTechnicalDetails: nil,
                showsTypingIndicator: false,
                preview: recognitionPreview(from: draft, localizer: localizer)
            )
        case let .saving(draft):
            return RecognitionActions(
                statusText: localizer.string("recognition.status.saving"),
                isLoading: true,
                buttonsDisabled: true,
                errorText: nil,
                errorTechnicalDetails: nil,
                showsTypingIndicator: false,
                preview: recognitionPreview(
                    from: draft,
                    localizer: localizer,
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
                statusText: localizer.string("recognition.status.failed"),
                isLoading: false,
                buttonsDisabled: false,
                errorText: issue.reason,
                errorTechnicalDetails: issue.technicalDetails,
                showsTypingIndicator: false,
                preview: nil
            )
        case let .saveFailure(draft, errorText):
            return RecognitionActions(
                statusText: localizer.string("recognition.status.saveFailed"),
                isLoading: false,
                buttonsDisabled: true,
                errorText: nil,
                errorTechnicalDetails: nil,
                showsTypingIndicator: false,
                preview: recognitionPreview(
                    from: draft,
                    localizer: localizer,
                    errorText: errorText
                )
            )
        }
    }

    private static func recognitionPreview(
        from draft: ImageRecognitionDraft,
        localizer: AppLocalizer,
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
                label: localizer.string("common.time"),
                value: timingText
            )
        ] + presentation.fields
        return RecognitionPreview(
            titleText: presentation.title,
            subtitleText: presentation.subtitle,
            fields: fields,
            saveButtonText: localizer.string("common.save"),
            cancelButtonText: localizer.string("common.cancel"),
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
        localizer: AppLocalizer = AppLocalizer(language: .system),
        locale: Locale = .autoupdatingCurrent,
        calendar: Calendar = .autoupdatingCurrent
    ) -> TodayScreenContent {
        let dateText = Self.headerDateText(now, locale: locale, calendar: calendar)
        let header = Header(
            dateText: dateText,
            todayText: localizer.string("today.title"),
            settingsButtonLabel: localizer.string("settings.title"),
            accessibilityLabel: localizer.string(
                "today.header.accessibility",
                dateText,
                localizer.string("today.title")
            )
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
            let sourceNotice = notice.map {
                mappedNotice(from: $0, localizer: localizer)
            }
            return TodayScreenContent(
                header: header,
                mode: .empty(sourceNotice),
                nowCard: nil,
                nextCard: nil,
                pinnedCard: nil,
                summary: fullTimelineSummary(localizer: localizer),
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
                    titleText: TodayStateCopy.permissionTitle(localizer),
                    bodyText: permissionBodyText(
                        for: authorization,
                        localizer: localizer
                    ),
                    buttonText: TodayStateCopy.permissionButton(localizer)
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
                calendar: calendar,
                localizer: localizer
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
                    retryText: TodayStateCopy.staleRetry(localizer)
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
                    titleText: TodayStateCopy.failureTitle(localizer),
                    bodyText: message,
                    retryText: TodayStateCopy.failureRetry(localizer)
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
                calendar: calendar,
                localizer: localizer
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

    private static func mappedNotice(
        from notice: TimelineAuthorizationNotice,
        localizer: AppLocalizer
    ) -> SourceNotice {
        SourceNotice(
            titleText: sourceNoticeTitle(notice, localizer: localizer),
            bodyText: sourceNoticeBody(notice, localizer: localizer),
            buttonText: localizer.string("today.permission.button"),
            accessibilityLabel: sourceNoticeAccessibility(
                notice,
                localizer: localizer
            )
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
        calendar: Calendar,
        localizer: AppLocalizer
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
                    localizer: localizer,
                    concurrentCount: snapshot.concurrentNowCount
                )
            },
            nextCard: nextItem.map {
                makeNextCard($0, now: now, locale: locale, localizer: localizer)
            },
            pinnedCard: pinnedItem.map {
                makePinnedCard(
                    $0,
                    now: now,
                    locale: locale,
                    calendar: calendar,
                    localizer: localizer,
                    pinOrigin: snapshot.pinOrigin
                )
            },
            summary: {
                let count = TodayPresentation.summaryCount(
                    for: snapshot,
                    now: now
                )
                return Summary(
                    titleText: localizer.string("today.summary.count", count),
                    accessibilityLabel: localizer.string(
                        "today.summary.accessibility",
                        count
                    )
                )
            }(),
            footer: Footer(
                generatedAtText: generatedAtText(
                    snapshot.generatedAt,
                    now: now,
                    locale: locale,
                    localizer: localizer
                )
            ),
            sourceNotice: sourceNotice(
                authorization: authorization,
                settings: settings,
                localizer: localizer
            )
        )
    }

    private static func fullTimelineSummary(localizer: AppLocalizer) -> Summary {
        Summary(
            titleText: localizer.string("today.summary.openTimeline"),
            accessibilityLabel: localizer.string("today.summary.openTimeline.accessibility")
        )
    }

    private static func sourceNotice(
        authorization: SourceAuthorization?,
        settings: TimelineSettings,
        localizer: AppLocalizer
    ) -> SourceNotice? {
        guard let notice = TimelineAuthorizationNotice.make(
            authorization: authorization,
            settings: settings
        ) else {
            return nil
        }

        return SourceNotice(
            titleText: sourceNoticeTitle(notice, localizer: localizer),
            bodyText: sourceNoticeBody(notice, localizer: localizer),
            buttonText: localizer.string("today.permission.button"),
            accessibilityLabel: sourceNoticeAccessibility(
                notice,
                localizer: localizer
            )
        )
    }

    private static func makeNowCard(
        _ item: TimelineItem,
        now: Date,
        locale: Locale,
        localizer: AppLocalizer,
        concurrentCount: Int
    ) -> Card {
        let progress = TodayPresentation.progress(
            start: item.startDate,
            end: item.endDate,
            now: now
        )
        let remainingText = relativeDurationText(
            until: countdownTargetDate(for: item, now: now) ?? now,
            relativeTo: now,
            localizer: localizer
        )
        let concurrentText = TodayPresentation.concurrentText(
            extraCount: max(0, concurrentCount),
            localizer: localizer
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
            statusText: localizer.string("today.card.now"),
            badgeText: nil,
            titleText: item.title,
            timeText: timeText,
            secondaryText: localizer.string("today.remaining", remainingText),
            tertiaryText: concurrentText,
            progressText: progressText
        )

        return Card(
            id: item.id,
            kind: .now,
            accent: .now,
            statusText: localizer.string("today.card.now"),
            badgeText: nil,
            symbolName: symbolName(for: item, fallback: .now),
            titleText: item.title,
            timeText: timeText,
            secondaryText: localizer.string("today.remaining", remainingText),
            tertiaryText: concurrentText,
            progress: progress,
            progressText: progressText,
            accessibilityLabel: accessibilityLabel
        )
    }

    private static func makeNextCard(
        _ item: TimelineItem,
        now: Date,
        locale: Locale,
        localizer: AppLocalizer
    ) -> Card {
        let timeText = timeRangeText(
            start: item.startDate,
            end: item.endDate,
            locale: locale
        )
        let countdown = relativeCountdownText(
            start: item.startDate,
            now: now,
            localizer: localizer
        )
        let accessibilityLabel = accessibilityLabel(
            statusText: localizer.string("today.card.next"),
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
            statusText: localizer.string("today.card.next"),
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
        localizer: AppLocalizer,
        pinOrigin: PinOrigin?
    ) -> Card {
        let badgeText = TodayPresentation.pinBadgeText(
            for: pinOrigin,
            localizer: localizer
        )
        let timeText = pinnedTimeText(
            for: item,
            now: now,
            locale: locale,
            calendar: calendar,
            localizer: localizer,
            includeLocation: true
        )
        let countdown = relativeCountdownText(
            target: countdownTargetDate(for: item, now: now),
            now: now,
            localizer: localizer
        )
        let accessibilityLabel = accessibilityLabel(
            statusText: localizer.string("pin.action.pin"),
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
            statusText: localizer.string("pin.action.pin"),
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
        localizer: AppLocalizer,
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
        if let kind = kindText(for: item.kind, localizer: localizer) {
            baseText = "\(startText) \(kind)"
        } else {
            baseText = startText
        }

        guard includeLocation, let location = item.location?.trimmingCharacters(in: .whitespacesAndNewlines), !location.isEmpty else {
            return baseText
        }

        return "\(baseText) · \(location)"
    }

    private static func kindText(
        for kind: TimelineKind,
        localizer: AppLocalizer
    ) -> String? {
        switch kind {
        case .flight:
            localizer.string("timeline.kind.action.flight")
        case .train:
            localizer.string("timeline.kind.action.train")
        case .interview:
            localizer.string("timeline.kind.interview")
        case .meeting:
            localizer.string("timeline.kind.meeting")
        case .deadline:
            localizer.string("timeline.kind.deadline")
        case .task:
            localizer.string("timeline.kind.task")
        case .travel, .unknown:
            nil
        }
    }

    private static func relativeCountdownText(
        start: Date,
        now: Date,
        localizer: AppLocalizer
    ) -> String {
        relativeCountdownText(
            target: start,
            now: now,
            localizer: localizer
        )
    }

    private static func relativeCountdownText(
        target: Date?,
        now: Date,
        localizer: AppLocalizer
    ) -> String {
        guard let target else {
            return ""
        }

        let interval = max(0, target.timeIntervalSince(now))
        return localizer.string(
            "today.countdown.prefix",
            localizer.durationText(for: interval)
        )
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
        relativeTo now: Date,
        localizer: AppLocalizer
    ) -> String {
        let interval = max(0, target.timeIntervalSince(now))
        return localizer.durationText(for: interval)
    }

    private static func generatedAtText(
        _ date: Date,
        now: Date,
        locale: Locale,
        localizer: AppLocalizer
    ) -> String {
        let interval = abs(date.timeIntervalSince(now))
        if interval < 60 {
            return localizer.string("today.updated.now")
        }

        let style = Date.FormatStyle()
            .hour(.defaultDigits(amPM: .omitted))
            .minute()
            .locale(locale)
        return localizer.string("today.updated.at", date.formatted(style))
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
            parts.append(progressText)
        }
        return parts.joined(separator: ", ")
    }

    private static func sourceNoticeTitle(
        _ notice: TimelineAuthorizationNotice,
        localizer: AppLocalizer
    ) -> String {
        localizer.string("today.sourceNotice.title")
    }

    private static func sourceNoticeBody(
        _ notice: TimelineAuthorizationNotice,
        localizer: AppLocalizer
    ) -> String {
        let sourceNames = notice.unavailableSources.map {
            sourceTitle($0, localizer: localizer)
        }
        return localizer.string(
            "today.sourceNotice.body",
            localizer.joinedList(sourceNames)
        )
    }

    private static func sourceNoticeAccessibility(
        _ notice: TimelineAuthorizationNotice,
        localizer: AppLocalizer
    ) -> String {
        localizer.string(
            "today.sourceNotice.accessibility",
            sourceNoticeTitle(notice, localizer: localizer),
            sourceNoticeBody(notice, localizer: localizer)
        )
    }

    private static func sourceTitle(
        _ source: TimelineSource,
        localizer: AppLocalizer
    ) -> String {
        switch source {
        case .calendar:
            localizer.string("source.calendar")
        case .reminder:
            localizer.string("source.reminders")
        case .external:
            "Pecker"
        }
    }

    private static func permissionBodyText(
        for authorization: SourceAuthorization,
        localizer: AppLocalizer
    ) -> String {
        let missing: [String] = [
            authorization.calendar == .fullAccess
                ? nil
                : localizer.string("source.calendar"),
            authorization.reminders == .fullAccess
                ? nil
                : localizer.string("source.reminders")
        ]
        .compactMap { $0 }

        guard !missing.isEmpty else {
            return localizer.string("today.permission.body.noMissing")
        }

        return localizer.string(
            "today.permission.body.missing",
            localizer.joinedList(missing)
        )
    }
}
