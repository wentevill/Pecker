import Foundation
import PeckerCore
import XCTest
@testable import Pecker

final class TodayPresentationTests: XCTestCase {
    @MainActor
    func testTodayViewSettingsViewModelSurfacesTodayLiveActivityStatus() {
        let store = SettingsStore(
            defaults: UserDefaults(
                suiteName: "TodayPresentationTests.\(UUID().uuidString)"
            )!
        )
        store.update { $0.liveActivityEnabled = true }

        let viewModel = TodayView.makeSettingsViewModel(
            settingsStore: store,
            authorization: .init(calendar: .fullAccess, reminders: .fullAccess),
            liveActivityStatusText: { "unavailable" },
            onSettingsChanged: {},
            openURL: { _ in }
        )

        XCTAssertEqual(
            viewModel.liveActivityStatusText(
                localizer: AppLocalizer(language: .simplifiedChinese)
            ),
            "\u{6682}\u{4e0d}\u{53ef}\u{7528}"
        )
    }

    func testPartialAuthorizationProducesNonBlockingNotice() {
        let snapshot = TodaySnapshot(
            schemaVersion: TodaySnapshot.currentSchemaVersion,
            generatedAt: Date(timeIntervalSince1970: 1_000),
            staleAfter: Date(timeIntervalSince1970: 2_000),
            items: [makeItem(id: "now")],
            nowItemID: "now",
            concurrentNowCount: 0,
            nextItemID: nil,
            pinnedItemID: nil,
            pinOrigin: nil
        )
        let content = TodayScreenContent.make(
            from: .content(snapshot),
            now: Date(timeIntervalSince1970: 1_000),
            authorization: .init(calendar: .denied, reminders: .fullAccess),
            settings: .init(),
            localizer: AppLocalizer(language: .simplifiedChinese),
            locale: Locale(identifier: "en_US_POSIX"),
            calendar: {
                var calendar = Calendar(identifier: .gregorian)
                calendar.locale = Locale(identifier: "en_US_POSIX")
                calendar.timeZone = TimeZone(secondsFromGMT: 0)!
                return calendar
            }()
        )

        XCTAssertEqual(content.sourceNotice?.titleText, "\u{90e8}\u{5206}\u{6743}\u{9650}\u{53d7}\u{9650}")
        XCTAssertEqual(content.sourceNotice?.buttonText, "\u{53bb}\u{7cfb}\u{7edf}\u{8bbe}\u{7f6e}")
    }

    func testEmptyStatePreservesPartialAuthorizationNotice() {
        let notice = TimelineAuthorizationNotice.make(
            authorization: .init(calendar: .denied, reminders: .fullAccess),
            settings: .init(calendarEnabled: true, remindersEnabled: true)
        )
        let content = TodayScreenContent.make(
            from: .empty(notice),
            now: Date(timeIntervalSince1970: 1_000),
            authorization: .init(calendar: .denied, reminders: .fullAccess),
            settings: .init(calendarEnabled: true, remindersEnabled: true),
            localizer: AppLocalizer(language: .simplifiedChinese),
            locale: Locale(identifier: "en_US_POSIX"),
            calendar: utcCalendar()
        )

        guard case let .empty(sourceNotice) = content.mode else {
            return XCTFail("Expected empty mode")
        }
        XCTAssertEqual(sourceNotice?.titleText, "\u{90e8}\u{5206}\u{6743}\u{9650}\u{53d7}\u{9650}")
        XCTAssertEqual(sourceNotice?.buttonText, "\u{53bb}\u{7cfb}\u{7edf}\u{8bbe}\u{7f6e}")
        XCTAssertEqual(content.sourceNotice, sourceNotice)
        XCTAssertEqual(content.summary?.titleText, "\u{67e5}\u{770b}\u{5b8c}\u{6574}\u{65f6}\u{95f4}\u{7ebf}")
    }

    func testEmptyStateOmitsNoticeWhenAllEnabledSourcesAreAuthorized() {
        let content = TodayScreenContent.make(
            from: .empty(nil),
            now: Date(timeIntervalSince1970: 1_000),
            authorization: .init(calendar: .fullAccess, reminders: .fullAccess),
            settings: .init(calendarEnabled: true, remindersEnabled: true),
            locale: Locale(identifier: "en_US_POSIX"),
            calendar: utcCalendar()
        )

        guard case let .empty(sourceNotice) = content.mode else {
            return XCTFail("Expected empty mode")
        }
        XCTAssertNil(sourceNotice)
        XCTAssertNil(content.sourceNotice)
    }

    func testSnapshotResolvesNowNextAndPinnedItemsSafely() throws {
        let items = [
            makeItem(id: "now"),
            makeItem(id: "next"),
            makeItem(id: "pinned")
        ]
        let snapshot = TodaySnapshot(
            schemaVersion: TodaySnapshot.currentSchemaVersion,
            generatedAt: Date(timeIntervalSince1970: 1_000),
            staleAfter: Date(timeIntervalSince1970: 2_000),
            items: items,
            nowItemID: "now",
            concurrentNowCount: 0,
            nextItemID: "next",
            pinnedItemID: "pinned",
            pinOrigin: .automatic
        )

        XCTAssertEqual(snapshot.resolvedNowItem?.id, "now")
        XCTAssertEqual(snapshot.resolvedNextItem?.id, "next")
        XCTAssertEqual(snapshot.resolvedPinnedItem?.id, "pinned")
        XCTAssertNil(snapshot.item(resolving: "missing"))
    }

    func testProgressClampsAndReturnsNilForInvalidIntervals() {
        let now = Date(timeIntervalSince1970: 1_000)
        let start = now.addingTimeInterval(-50)
        let end = now.addingTimeInterval(50)

        XCTAssertEqual(
            try XCTUnwrap(
                TodayPresentation.progress(
                    start: start,
                    end: end,
                    now: now
                )
            ),
            0.5,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            try XCTUnwrap(
                TodayPresentation.progress(
                    start: start,
                    end: end,
                    now: start.addingTimeInterval(-10)
                )
            ),
            0,
            accuracy: 0.0001
        )
        XCTAssertEqual(
            try XCTUnwrap(
                TodayPresentation.progress(
                    start: start,
                    end: end,
                    now: end.addingTimeInterval(10)
                )
            ),
            1,
            accuracy: 0.0001
        )
        XCTAssertNil(
            TodayPresentation.progress(start: nil, end: end, now: now)
        )
        XCTAssertNil(
            TodayPresentation.progress(start: start, end: nil, now: now)
        )
        XCTAssertNil(
            TodayPresentation.progress(
                start: end,
                end: start,
                now: now
            )
        )
    }

    func testConcurrentTextIsShownOnlyForAdditionalActiveItems() {
        let localizer = AppLocalizer(language: .simplifiedChinese)
        XCTAssertNil(
            TodayPresentation.concurrentText(
                extraCount: 0,
                localizer: localizer
            )
        )
        XCTAssertEqual(
            TodayPresentation.concurrentText(
                extraCount: 2,
                localizer: localizer
            ),
            "\u{53e6}\u{6709} 2 \u{9879}\u{8fdb}\u{884c}\u{4e2d}"
        )
    }

    func testNowCardCountdownUsesEndDateForRunningItem() {
        let now = Date(timeIntervalSince1970: 1_000)
        let item = TimelineItem(
            id: "now",
            sourceIdentifier: "now",
            title: "Running",
            startDate: now.addingTimeInterval(-10 * 60),
            endDate: now.addingTimeInterval(5 * 60),
            isAllDay: false,
            source: .calendar,
            kind: .meeting,
            location: nil,
            notes: nil
        )
        let snapshot = TodaySnapshot(
            schemaVersion: TodaySnapshot.currentSchemaVersion,
            generatedAt: now,
            staleAfter: now.addingTimeInterval(900),
            items: [item],
            nowItemID: item.id,
            concurrentNowCount: 0,
            nextItemID: nil,
            pinnedItemID: nil,
            pinOrigin: nil
        )

        let content = TodayScreenContent.make(
            from: .content(snapshot),
            now: now,
            localizer: AppLocalizer(language: .simplifiedChinese),
            locale: Locale(identifier: "zh_Hans_CN"),
            calendar: utcCalendar()
        )

        XCTAssertEqual(content.nowCard?.secondaryText, "\u{5269}\u{4f59} 5 \u{5206}\u{949f}")
    }

    func testPinnedCountdownUsesEndDateWhenRunningAndStartDateBeforeStart() {
        let now = Date(timeIntervalSince1970: 1_000)
        let runningPinned = TimelineItem(
            id: "running",
            sourceIdentifier: "running",
            title: "Running Train",
            startDate: now.addingTimeInterval(-10 * 60),
            endDate: now.addingTimeInterval(7 * 60),
            isAllDay: false,
            source: .calendar,
            kind: .train,
            location: nil,
            notes: nil
        )
        let upcomingPinned = TimelineItem(
            id: "upcoming",
            sourceIdentifier: "upcoming",
            title: "Upcoming Train",
            startDate: now.addingTimeInterval(12 * 60),
            endDate: now.addingTimeInterval(60 * 60),
            isAllDay: false,
            source: .calendar,
            kind: .train,
            location: nil,
            notes: nil
        )

        let runningContent = TodayScreenContent.make(
            from: .content(snapshot(pinned: runningPinned, now: now)),
            now: now,
            localizer: AppLocalizer(language: .simplifiedChinese),
            locale: Locale(identifier: "zh_Hans_CN"),
            calendar: utcCalendar()
        )
        let upcomingContent = TodayScreenContent.make(
            from: .content(snapshot(pinned: upcomingPinned, now: now)),
            now: now,
            localizer: AppLocalizer(language: .simplifiedChinese),
            locale: Locale(identifier: "zh_Hans_CN"),
            calendar: utcCalendar()
        )

        XCTAssertEqual(runningContent.pinnedCard?.tertiaryText, "\u{8fd8}\u{6709} 7 \u{5206}\u{949f}")
        XCTAssertEqual(upcomingContent.pinnedCard?.tertiaryText, "\u{8fd8}\u{6709} 12 \u{5206}\u{949f}")
    }

    func testPinBadgeCopyMatchesOrigin() {
        let localizer = AppLocalizer(language: .simplifiedChinese)
        XCTAssertEqual(
            TodayPresentation.pinBadgeText(
                for: .automatic,
                localizer: localizer
            ),
            "\u{81ea}\u{52a8}\u{63a8}\u{8350}"
        )
        XCTAssertEqual(
            TodayPresentation.pinBadgeText(
                for: .manual,
                localizer: localizer
            ),
            "\u{624b}\u{52a8}\u{56fa}\u{5b9a}"
        )
        XCTAssertNil(
            TodayPresentation.pinBadgeText(for: nil, localizer: localizer)
        )
    }

    func testRecognitionActionsHiddenUntilRecognitionIsEnabled() {
        XCTAssertNil(
            TodayScreenContent.recognitionActions(
                settings: TimelineSettings(aiRecognitionMode: .off),
                phase: .idle
            )
        )
        XCTAssertNil(
            TodayScreenContent.recognitionActions(
                settings: TimelineSettings(
                    aiRecognitionMode: .openAI,
                    openAIAPIKeyConfigured: false
                ),
                phase: .idle
            )
        )
    }

    func testRecognitionActionsSurfaceTypingPreviewSavingAndFailure() throws {
        let settings = TimelineSettings(
            aiRecognitionMode: .openAI,
            openAIAPIKeyConfigured: true
        )
        let localizer = AppLocalizer(language: .simplifiedChinese)
        let draft = ImageRecognitionDraft(
            id: "image:draft-1",
            sourceIdentifier: "draft-1",
            source: .importedImage,
            filename: "ticket.jpg",
            imageData: Data([1, 2, 3]),
            recognizedAt: Date(timeIntervalSince1970: 5_000),
            startDate: Date(timeIntervalSince1970: 6_000),
            endDate: Date(timeIntervalSince1970: 7_000),
            template: .trainTicket(.init(
                trainNumber: "G123",
                departureStation: "\u{4e0a}\u{6d77}\u{8679}\u{6865}",
                arrivalStation: "\u{5317}\u{4eac}\u{5357}",
                departureTimeText: "09:24",
                arrivalTimeText: nil,
                carriageNumber: "08",
                seatNumber: "03A",
                checkInGate: nil,
                passengerName: nil,
                ticketNumber: nil
            ))
        )

        let idle = try XCTUnwrap(
            TodayScreenContent.recognitionActions(
                settings: settings,
                phase: .idle,
                localizer: localizer
            )
        )
        XCTAssertEqual(idle.statusText, "\u{7b49}\u{5f85}\u{56fe}\u{7247}")
        XCTAssertFalse(idle.isLoading)
        XCTAssertFalse(idle.buttonsDisabled)
        XCTAssertNil(idle.errorText)
        XCTAssertFalse(idle.showsTypingIndicator)
        XCTAssertNil(idle.preview)

        let recognizing = try XCTUnwrap(
            TodayScreenContent.recognitionActions(
                settings: settings,
                phase: .recognizing,
                localizer: localizer
            )
        )
        XCTAssertEqual(recognizing.statusText, "\u{6b63}\u{5728}\u{8bc6}\u{522b}")
        XCTAssertTrue(recognizing.isLoading)
        XCTAssertTrue(recognizing.buttonsDisabled)
        XCTAssertTrue(recognizing.showsTypingIndicator)
        XCTAssertNil(recognizing.preview)

        let confirmation = try XCTUnwrap(
            TodayScreenContent.recognitionActions(
                settings: settings,
                phase: .awaitingConfirmation(draft),
                localizer: localizer
            )
        )
        XCTAssertEqual(confirmation.statusText, "\u{8bc6}\u{522b}\u{5b8c}\u{6210}，\u{786e}\u{8ba4}\u{540e}\u{4fdd}\u{5b58}")
        XCTAssertFalse(confirmation.isLoading)
        XCTAssertTrue(confirmation.buttonsDisabled)
        XCTAssertEqual(confirmation.preview?.titleText, "G123")
        XCTAssertEqual(confirmation.preview?.subtitleText, "\u{4e0a}\u{6d77}\u{8679}\u{6865} → \u{5317}\u{4eac}\u{5357}")
        XCTAssertEqual(confirmation.preview?.fields.first?.label, "\u{65f6}\u{95f4}")
        XCTAssertFalse(try XCTUnwrap(confirmation.preview).buttonsDisabled)

        let saving = try XCTUnwrap(
            TodayScreenContent.recognitionActions(
                settings: settings,
                phase: .saving(draft),
                localizer: localizer
            )
        )
        XCTAssertEqual(saving.statusText, "\u{6b63}\u{5728}\u{4fdd}\u{5b58}")
        XCTAssertTrue(saving.isLoading)
        XCTAssertTrue(try XCTUnwrap(saving.preview).buttonsDisabled)

        let saveFailure = try XCTUnwrap(
            TodayScreenContent.recognitionActions(
                settings: settings,
                phase: .saveFailure(draft, "\u{4fdd}\u{5b58}\u{5931}\u{8d25}，\u{8bf7}\u{91cd}\u{8bd5}。"),
                localizer: localizer
            )
        )
        XCTAssertEqual(saveFailure.preview?.errorText, "\u{4fdd}\u{5b58}\u{5931}\u{8d25}，\u{8bf7}\u{91cd}\u{8bd5}。")
        XCTAssertFalse(try XCTUnwrap(saveFailure.preview).buttonsDisabled)

        let failure = try XCTUnwrap(
            TodayScreenContent.recognitionActions(
                settings: settings,
                phase: .failure(.init(
                    reason: "\u{670d}\u{52a1}\u{8fd4}\u{56de} 429：\u{8bf7}\u{6c42}\u{8fc7}\u{4e8e}\u{9891}\u{7e41}",
                    technicalDetails: "\u{9636}\u{6bb5}：\u{7ed3}\u{679c}\u{6838}\u{5bf9}\nHTTP 429\n\u{9519}\u{8bef}\u{7801}：rate_limit"
                )),
                localizer: localizer
            )
        )
        XCTAssertEqual(failure.statusText, "\u{8bc6}\u{522b}\u{5931}\u{8d25}")
        XCTAssertFalse(failure.isLoading)
        XCTAssertFalse(failure.buttonsDisabled)
        XCTAssertEqual(failure.errorText, "\u{670d}\u{52a1}\u{8fd4}\u{56de} 429：\u{8bf7}\u{6c42}\u{8fc7}\u{4e8e}\u{9891}\u{7e41}")
        XCTAssertEqual(
            failure.errorTechnicalDetails,
            "\u{9636}\u{6bb5}：\u{7ed3}\u{679c}\u{6838}\u{5bf9}\nHTTP 429\n\u{9519}\u{8bef}\u{7801}：rate_limit"
        )
    }

    func testSummaryCountIncludesActiveAndUpcomingButExcludesElapsedAndCompleted() {
        let now = Date(timeIntervalSince1970: 1_000)
        let snapshot = TodaySnapshot(
            schemaVersion: TodaySnapshot.currentSchemaVersion,
            generatedAt: now,
            staleAfter: Date(timeIntervalSince1970: 2_000),
            items: [
                makeItem(
                    id: "active",
                    startDate: now.addingTimeInterval(-100),
                    endDate: now.addingTimeInterval(100)
                ),
                makeItem(
                    id: "upcoming",
                    startDate: now.addingTimeInterval(200),
                    endDate: now.addingTimeInterval(300)
                ),
                makeItem(
                    id: "elapsed",
                    startDate: now.addingTimeInterval(-300),
                    endDate: now.addingTimeInterval(-200)
                ),
                makeItem(
                    id: "completed",
                    startDate: now.addingTimeInterval(400),
                    endDate: nil,
                    isCompleted: true
                )
            ],
            nowItemID: "active",
            concurrentNowCount: 0,
            nextItemID: "upcoming",
            pinnedItemID: nil,
            pinOrigin: nil
        )

        XCTAssertEqual(
            TodayPresentation.summaryCount(for: snapshot, now: now),
            2
        )
    }

    func testStateCopyIsStable() {
        let localizer = AppLocalizer(language: .simplifiedChinese)
        XCTAssertEqual(
            TodayStateCopy.loadingTitle(localizer),
            "\u{52a0}\u{8f7d}\u{4e2d}"
        )
        XCTAssertEqual(
            TodayStateCopy.emptyTitle(localizer),
            "\u{4eca}\u{5929}\u{6682}\u{65f6}\u{7a7a}\u{95f2}"
        )
        XCTAssertEqual(
            TodayStateCopy.permissionTitle(localizer),
            "\u{9700}\u{8981}\u{8bbf}\u{95ee}\u{65e5}\u{5386}\u{4e0e}\u{63d0}\u{9192}\u{4e8b}\u{9879}"
        )
        XCTAssertEqual(
            TodayStateCopy.staleBanner(localizer),
            "\u{6570}\u{636e}\u{53ef}\u{80fd}\u{5df2}\u{8fc7}\u{65f6}"
        )
        XCTAssertEqual(
            TodayStateCopy.failureTitle(localizer),
            "\u{4eca}\u{5929}\u{6682}\u{65f6}\u{4e0d}\u{53ef}\u{7528}"
        )
    }

    func testHeaderAccessibilityLabelCombinesDateAndTodayTitle() {
        let content = TodayScreenContent.make(
            from: .empty(nil),
            now: Date(timeIntervalSince1970: 1_735_693_200),
            locale: Locale(identifier: "en_US_POSIX"),
            calendar: {
                var calendar = Calendar(identifier: .gregorian)
                calendar.locale = Locale(identifier: "en_US_POSIX")
                calendar.timeZone = TimeZone(secondsFromGMT: 0)!
                return calendar
            }()
        )

        XCTAssertEqual(
            content.header.accessibilityLabel,
            "Wednesday, January 1, Today"
        )
    }

    func testHeaderDateTextUsesInjectedCalendarAndTimeZone() {
        let date = Date(timeIntervalSince1970: 1_735_693_200)
        let locale = Locale(identifier: "en_US_POSIX")

        var utcCalendar = Calendar(identifier: .gregorian)
        utcCalendar.locale = locale
        utcCalendar.timeZone = TimeZone(secondsFromGMT: 0)!

        var losAngelesCalendar = Calendar(identifier: .gregorian)
        losAngelesCalendar.locale = locale
        losAngelesCalendar.timeZone = TimeZone(secondsFromGMT: -8 * 3_600)!

        let utcContent = TodayScreenContent.make(
            from: .empty(nil),
            now: date,
            locale: locale,
            calendar: utcCalendar
        )
        let losAngelesContent = TodayScreenContent.make(
            from: .empty(nil),
            now: date,
            locale: locale,
            calendar: losAngelesCalendar
        )

        XCTAssertEqual(utcContent.header.dateText, "Wednesday, January 1")
        XCTAssertEqual(losAngelesContent.header.dateText, "Tuesday, December 31")
    }

    private func utcCalendar() -> Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "en_US_POSIX")
        calendar.timeZone = TimeZone(secondsFromGMT: 0)!
        return calendar
    }

    private func makeItem(id: String) -> TimelineItem {
        makeItem(
            id: id,
            startDate: Date(timeIntervalSince1970: 1_000),
            endDate: Date(timeIntervalSince1970: 1_100)
        )
    }

    private func makeItem(
        id: String,
        startDate: Date,
        endDate: Date?,
        isCompleted: Bool = false
    ) -> TimelineItem {
        TimelineItem(
            id: id,
            sourceIdentifier: id,
            title: id.capitalized,
            startDate: startDate,
            endDate: endDate,
            isAllDay: false,
            source: .calendar,
            kind: .meeting,
            location: "Room 1",
            notes: nil,
            isCompleted: isCompleted
        )
    }

    private func snapshot(
        pinned item: TimelineItem,
        now: Date
    ) -> TodaySnapshot {
        TodaySnapshot(
            schemaVersion: TodaySnapshot.currentSchemaVersion,
            generatedAt: now,
            staleAfter: now.addingTimeInterval(900),
            items: [item],
            nowItemID: nil,
            concurrentNowCount: 0,
            nextItemID: nil,
            pinnedItemID: item.id,
            pinOrigin: .automatic
        )
    }
}
