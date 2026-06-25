import Foundation
import Testing
@testable import PeckerCore

@Suite struct TimelineEngineTests {
    @Test func selectsHighestPriorityNowAndCountsConflicts() {
        let now = Date(timeIntervalSince1970: 1_000)
        let meeting = item("meeting", .meeting, 900, 1_100)
        let flight = item("flight", .flight, 950, 1_200)

        let snapshot = TimelineEngine().makeSnapshot(
            items: [meeting, flight],
            now: now,
            settings: .init(),
            staleInterval: 900
        )

        #expect(snapshot.nowItemID == flight.id)
        #expect(snapshot.concurrentNowCount == 1)
    }

    @Test func excludesItemAtExactEndAndSelectsEarliestNext() {
        let now = Date(timeIntervalSince1970: 1_000)
        let ended = item("ended", .meeting, 900, 1_000)
        let later = item("later", .meeting, 1_200, 1_300)
        let next = item("next", .task, 1_100, 1_200)

        let snapshot = TimelineEngine().makeSnapshot(
            items: [later, ended, next],
            now: now,
            settings: .init(),
            staleInterval: 900
        )

        #expect(snapshot.nowItemID == nil)
        #expect(snapshot.nextItemID == next.id)
    }

    @Test func includesItemAtExactStartAsNow() {
        let now = Date(timeIntervalSince1970: 1_000)
        let starting = item("starting", .meeting, 1_000, 1_100)

        let snapshot = TimelineEngine().makeSnapshot(
            items: [starting],
            now: now,
            settings: .init(),
            staleInterval: 900
        )

        #expect(snapshot.nowItemID == starting.id)
        #expect(snapshot.concurrentNowCount == 0)
    }

    @Test func selectsCrossMidnightEventAsNowBasedOnItsInterval() {
        let event = item(
            "Cross-midnight maintenance",
            .meeting,
            1_782_084_600, // 2026-06-21T23:30:00Z
            1_782_090_000  // 2026-06-22T01:00:00Z
        )
        let now = Date(
            timeIntervalSince1970: 1_782_087_300 // 2026-06-22T00:15:00Z
        )

        let snapshot = TimelineEngine().makeSnapshot(
            items: [event],
            now: now,
            settings: .init(),
            staleInterval: 900
        )

        #expect(snapshot.nowItemID == event.id)
    }

    @Test func reminderWithoutEndDateDoesNotBecomeCurrentAfterDueDate() {
        let now = Date(
            timeIntervalSince1970: 1_782_122_400 // 2026-06-22T10:00:00Z
        )
        let overdueReminder = item(
            "Submit expense report",
            .unknown,
            1_782_118_800, // 2026-06-22T09:00:00Z
            nil,
            source: .reminder
        )

        let snapshot = TimelineEngine().makeSnapshot(
            items: [overdueReminder],
            now: now,
            settings: .init(),
            staleInterval: 900
        )

        #expect(snapshot.nowItemID == nil)
        #expect(snapshot.nextItemID == nil)
    }

    @Test func ranksNowKindsInApprovedOrder() {
        let now = Date(timeIntervalSince1970: 1_000)
        let rankedItems = [
            item("flight", .flight, 900, 1_100),
            item("train", .train, 900, 1_100),
            item("interview", .interview, 900, 1_100),
            item("meeting", .meeting, 900, 1_100),
            item("deadline", .deadline, 900, 1_100),
            item("task", .task, 900, 1_100),
            item("unknown", .unknown, 900, 1_100)
        ]

        for index in rankedItems.indices {
            let candidates = Array(rankedItems[index...].reversed())
            let snapshot = TimelineEngine().makeSnapshot(
                items: candidates,
                now: now,
                settings: .init(),
                staleInterval: 900
            )

            #expect(snapshot.nowItemID == rankedItems[index].id)
            #expect(snapshot.concurrentNowCount == candidates.count - 1)
        }
    }

    @Test func classifiesUnknownActiveFlightBeforeNowSelection() {
        let now = Date(timeIntervalSince1970: 1_000)
        let meeting = item("Team meeting", .meeting, 900, 1_100)
        let flight = item("SQ833", .unknown, 950, 1_200)

        let snapshot = TimelineEngine().makeSnapshot(
            items: [meeting, flight],
            now: now,
            settings: .init(),
            staleInterval: 900
        )

        #expect(snapshot.items.first { $0.id == flight.id }?.kind == .flight)
        #expect(snapshot.nowItemID == flight.id)
        #expect(snapshot.pinnedItemID == flight.id)
        #expect(snapshot.pinOrigin == .automatic)
    }

    @Test func classifiesUnknownFutureFlightBeforeAutomaticPinSelection() {
        let now = Date(timeIntervalSince1970: 1_000)
        let meeting = item("Team meeting", .meeting, 1_050, 1_150)
        let flight = item("SQ833", .unknown, 1_200, 1_400)

        let snapshot = TimelineEngine().makeSnapshot(
            items: [meeting, flight],
            now: now,
            settings: .init(),
            staleInterval: 900
        )

        #expect(snapshot.items.first { $0.id == flight.id }?.kind == .flight)
        #expect(snapshot.pinnedItemID == flight.id)
        #expect(snapshot.pinOrigin == .automatic)
    }

    @Test func enrichesUnknownTrainWithTrainTicketTemplate() {
        let now = Date(timeIntervalSince1970: 1_000)
        let train = TimelineItem(
            id: "calendar:train",
            sourceIdentifier: "train",
            title: "G123 上海虹桥 → 北京南",
            startDate: Date(timeIntervalSince1970: 1_200),
            endDate: Date(timeIntervalSince1970: 1_400),
            isAllDay: false,
            source: .calendar,
            kind: .unknown,
            location: "检票口 B7",
            notes: "08车 03A"
        )

        let snapshot = TimelineEngine().makeSnapshot(
            items: [train],
            now: now,
            settings: .init(),
            staleInterval: 900
        )

        let enriched = snapshot.items.first { $0.id == train.id }
        #expect(enriched?.kind == .train)
        guard case let .trainTicket(ticket) = enriched?.template else {
            Issue.record("Expected train ticket template")
            return
        }
        #expect(ticket.trainNumber == "G123")
        #expect(ticket.departureStation == "上海虹桥")
        #expect(ticket.arrivalStation == "北京南")
        #expect(ticket.carriageNumber == "08")
        #expect(ticket.seatNumber == "03A")
        #expect(ticket.checkInGate == "B7")
    }

    @Test func clearsTravelTemplateWhenTravelEventsAreHidden() {
        let now = Date(timeIntervalSince1970: 1_000)
        let train = TimelineItem(
            id: "calendar:train",
            sourceIdentifier: "train",
            title: "G123 上海虹桥 → 北京南",
            startDate: Date(timeIntervalSince1970: 1_200),
            endDate: Date(timeIntervalSince1970: 1_400),
            isAllDay: false,
            source: .calendar,
            kind: .unknown,
            location: nil,
            notes: nil
        )

        let snapshot = TimelineEngine().makeSnapshot(
            items: [train],
            now: now,
            settings: .init(showTravelEvents: false),
            staleInterval: 900
        )

        let hidden = snapshot.items.first { $0.id == train.id }
        #expect(hidden?.kind == .unknown)
        #expect(hidden?.template == nil)
    }

    @Test func classifiesUnknownReminderAsTask() {
        let now = Date(timeIntervalSince1970: 1_000)
        let reminder = item(
            "Buy milk",
            .unknown,
            900,
            1_100,
            source: .reminder
        )

        let snapshot = TimelineEngine().makeSnapshot(
            items: [reminder],
            now: now,
            settings: .init(),
            staleInterval: 900
        )

        #expect(snapshot.items.first?.kind == .task)
        #expect(snapshot.nowItemID == reminder.id)
    }

    @Test func preservesAlreadySpecificKindDuringClassification() {
        let now = Date(timeIntervalSince1970: 1_000)
        let meeting = item("SQ833", .meeting, 900, 1_100)

        let snapshot = TimelineEngine().makeSnapshot(
            items: [meeting],
            now: now,
            settings: .init(),
            staleInterval: 900
        )

        #expect(snapshot.items.first?.kind == .meeting)
    }

    @Test func classifiesUnknownFlightBeforeHiddenTravelDowngrade() {
        let now = Date(timeIntervalSince1970: 1_000)
        let flight = item("SQ833", .unknown, 900, 1_100)
        let meeting = item("Team meeting", .meeting, 900, 1_200)

        let snapshot = TimelineEngine().makeSnapshot(
            items: [flight, meeting],
            now: now,
            settings: .init(showTravelEvents: false),
            staleInterval: 900
        )

        #expect(snapshot.items.first { $0.id == flight.id }?.kind == .unknown)
        #expect(snapshot.nowItemID == meeting.id)
        #expect(snapshot.pinnedItemID == meeting.id)
    }

    @Test func appliesStableNowTieBreakers() {
        let now = Date(timeIntervalSince1970: 1_000)
        let earliestEnd = item("earliest-end", .meeting, 800, 1_050)
        let laterEnd = item("later-end", .meeting, 700, 1_100)
        let endSnapshot = TimelineEngine().makeSnapshot(
            items: [laterEnd, earliestEnd],
            now: now,
            settings: .init(),
            staleInterval: 900
        )

        let earliestStart = item("earliest-start", .meeting, 700, 1_100)
        let laterStart = item("later-start", .meeting, 800, 1_100)
        let startSnapshot = TimelineEngine().makeSnapshot(
            items: [laterStart, earliestStart],
            now: now,
            settings: .init(),
            staleInterval: 900
        )

        let alpha = item("Alpha", .meeting, 800, 1_100)
        let beta = item("Beta", .meeting, 800, 1_100)
        let titleSnapshot = TimelineEngine().makeSnapshot(
            items: [beta, alpha],
            now: now,
            settings: .init(),
            staleInterval: 900
        )

        #expect(endSnapshot.nowItemID == earliestEnd.id)
        #expect(startSnapshot.nowItemID == earliestStart.id)
        #expect(titleSnapshot.nowItemID == alpha.id)
    }

    @Test func selectsEarliestFutureTimedItemAsNext() {
        let now = Date(timeIntervalSince1970: 1_000)
        let laterFlight = item("later-flight", .flight, 1_200, 1_300)
        let earlierUnknown = item("earlier-unknown", .unknown, 1_100, 1_150)

        let snapshot = TimelineEngine().makeSnapshot(
            items: [laterFlight, earlierUnknown],
            now: now,
            settings: .init(),
            staleInterval: 900
        )

        #expect(snapshot.nextItemID == earlierUnknown.id)
    }

    @Test func excludesAllDayItemsFromNowAndNext() {
        let now = Date(timeIntervalSince1970: 1_000)
        let activeAllDay = item(
            "active-all-day",
            .meeting,
            900,
            1_100,
            isAllDay: true
        )
        let futureAllDay = item(
            "future-all-day",
            .flight,
            1_050,
            1_200,
            isAllDay: true
        )

        let snapshot = TimelineEngine().makeSnapshot(
            items: [futureAllDay, activeAllDay],
            now: now,
            settings: .init(),
            staleInterval: 900
        )

        #expect(snapshot.items.count == 2)
        #expect(snapshot.nowItemID == nil)
        #expect(snapshot.concurrentNowCount == 0)
        #expect(snapshot.nextItemID == nil)
    }

    @Test func filtersDisabledCalendarAndReminderSources() {
        let now = Date(timeIntervalSince1970: 1_000)
        let calendar = item(
            "calendar",
            .meeting,
            900,
            1_100,
            source: .calendar
        )
        let reminder = item(
            "reminder",
            .task,
            950,
            1_200,
            source: .reminder
        )

        let calendarDisabled = TimelineEngine().makeSnapshot(
            items: [calendar, reminder],
            now: now,
            settings: .init(calendarEnabled: false),
            staleInterval: 900
        )
        let remindersDisabled = TimelineEngine().makeSnapshot(
            items: [calendar, reminder],
            now: now,
            settings: .init(remindersEnabled: false),
            staleInterval: 900
        )

        #expect(calendarDisabled.items.map(\.id) == [reminder.id])
        #expect(calendarDisabled.nowItemID == reminder.id)
        #expect(remindersDisabled.items.map(\.id) == [calendar.id])
        #expect(remindersDisabled.nowItemID == calendar.id)
    }

    @Test func downgradesTravelKindsWhenTravelEventsAreHidden() {
        let now = Date(timeIntervalSince1970: 1_000)
        let flight = item("flight", .flight, 900, 1_050)
        let train = item("train", .train, 1_100, 1_200)
        let travel = item("travel", .travel, 1_200, 1_300)
        let meeting = item("meeting", .meeting, 900, 1_100)

        let snapshot = TimelineEngine().makeSnapshot(
            items: [flight, train, travel, meeting],
            now: now,
            settings: .init(showTravelEvents: false),
            staleInterval: 900
        )

        #expect(snapshot.items.first { $0.id == flight.id }?.kind == .unknown)
        #expect(snapshot.items.first { $0.id == train.id }?.kind == .unknown)
        #expect(snapshot.items.first { $0.id == travel.id }?.kind == .unknown)
        #expect(snapshot.items.first { $0.id == meeting.id }?.kind == .meeting)
        #expect(snapshot.nowItemID == meeting.id)
        #expect(snapshot.nextItemID == train.id)
    }

    @Test func manualPinOverridesAutomaticFlight() {
        let now = Date(timeIntervalSince1970: 1_000)
        let flight = item("flight", .flight, 1_100, 1_200)
        let interview = item("interview", .interview, 1_300, 1_400)

        let snapshot = TimelineEngine().makeSnapshot(
            items: [flight, interview],
            now: now,
            settings: .init(
                manualPinnedSourceIdentifier: interview.sourceIdentifier
            ),
            staleInterval: 900
        )

        #expect(snapshot.pinnedItemID == interview.id)
        #expect(snapshot.pinOrigin == .manual)
    }

    @Test func missingManualPinFallsBackToAutomatic() {
        let now = Date(timeIntervalSince1970: 1_000)
        let flight = item("flight", .flight, 1_100, 1_200)

        let snapshot = TimelineEngine().makeSnapshot(
            items: [flight],
            now: now,
            settings: .init(manualPinnedSourceIdentifier: "missing"),
            staleInterval: 900
        )

        #expect(snapshot.pinnedItemID == flight.id)
        #expect(snapshot.pinOrigin == .automatic)
    }

    @Test func completedItemsCannotBePinned() {
        let now = Date(timeIntervalSince1970: 1_000)
        let completedFlight = item("flight", .flight, 800, 1_000)

        let snapshot = TimelineEngine().makeSnapshot(
            items: [completedFlight],
            now: now,
            settings: .init(
                manualPinnedSourceIdentifier: completedFlight.sourceIdentifier
            ),
            staleInterval: 900
        )

        #expect(snapshot.pinnedItemID == nil)
        #expect(snapshot.pinOrigin == nil)
    }

    @Test func automaticPriorityIsFlightTrainInterviewMeetingDeadline() {
        let now = Date(timeIntervalSince1970: 1_000)
        let rankedItems = [
            item("flight", .flight, 1_500, 1_600),
            item("train", .train, 1_100, 1_200),
            item("interview", .interview, 1_050, 1_150),
            item("meeting", .meeting, 1_025, 1_125),
            item("deadline", .deadline, 1_010, 1_110)
        ]

        for index in rankedItems.indices {
            let candidates = Array(rankedItems[index...].reversed())
            let snapshot = TimelineEngine().makeSnapshot(
                items: candidates,
                now: now,
                settings: .init(),
                staleInterval: 900
            )

            #expect(snapshot.pinnedItemID == rankedItems[index].id)
            #expect(snapshot.pinOrigin == .automatic)
        }
    }

    @Test func automaticPinUsesEarlierStartWithinKind() {
        let now = Date(timeIntervalSince1970: 1_000)
        let earlier = item("earlier", .meeting, 1_100, 1_300)
        let later = item("later", .meeting, 1_200, 1_250)

        let snapshot = TimelineEngine().makeSnapshot(
            items: [later, earlier],
            now: now,
            settings: .init(),
            staleInterval: 900
        )

        #expect(snapshot.pinnedItemID == earlier.id)
        #expect(snapshot.pinOrigin == .automatic)
    }

    @Test func automaticPinUsesStableItemTieBreakers() {
        let now = Date(timeIntervalSince1970: 1_000)
        let earliestEnd = item("earliest-end", .meeting, 1_100, 1_200)
        let laterEnd = item("later-end", .meeting, 1_100, 1_300)
        let endSnapshot = TimelineEngine().makeSnapshot(
            items: [laterEnd, earliestEnd],
            now: now,
            settings: .init(),
            staleInterval: 900
        )

        let alpha = item("Alpha", .meeting, 1_100, 1_200)
        let beta = item("Beta", .meeting, 1_100, 1_200)
        let titleSnapshot = TimelineEngine().makeSnapshot(
            items: [beta, alpha],
            now: now,
            settings: .init(),
            staleInterval: 900
        )

        #expect(endSnapshot.pinnedItemID == earliestEnd.id)
        #expect(titleSnapshot.pinnedItemID == alpha.id)
    }

    @Test func manualPinMustMatchSourceIdentifierAndBeUnfinished() {
        let now = Date(timeIntervalSince1970: 1_000)
        let completedTask = item("shared", .task, 800, 1_000)
        let unmatchedFlight = item("flight", .flight, 1_100, 1_200)

        let completedMatchSnapshot = TimelineEngine().makeSnapshot(
            items: [unmatchedFlight, completedTask],
            now: now,
            settings: .init(manualPinnedSourceIdentifier: "shared"),
            staleInterval: 900
        )
        let IDOnlyMatchSnapshot = TimelineEngine().makeSnapshot(
            items: [unmatchedFlight],
            now: now,
            settings: .init(manualPinnedSourceIdentifier: unmatchedFlight.id),
            staleInterval: 900
        )

        #expect(completedMatchSnapshot.pinnedItemID == unmatchedFlight.id)
        #expect(completedMatchSnapshot.pinOrigin == .automatic)
        #expect(IDOnlyMatchSnapshot.pinnedItemID == unmatchedFlight.id)
        #expect(IDOnlyMatchSnapshot.pinOrigin == .automatic)
    }

    @Test func manualPinCanSelectUnfinishedTaskWithoutEndDate() {
        let now = Date(timeIntervalSince1970: 1_000)
        let task = item("task", .task, 1_000, nil)
        let flight = item("flight", .flight, 1_100, 1_200)

        let snapshot = TimelineEngine().makeSnapshot(
            items: [flight, task],
            now: now,
            settings: .init(
                manualPinnedSourceIdentifier: task.sourceIdentifier
            ),
            staleInterval: 900
        )

        #expect(snapshot.pinnedItemID == task.id)
        #expect(snapshot.pinOrigin == .manual)
    }

    @Test func allDayUnfinishedImportantEventIsEligibleForAutomaticPin() {
        let now = Date(timeIntervalSince1970: 1_000)
        let allDayInterview = item(
            "all-day-interview",
            .interview,
            900,
            1_100,
            isAllDay: true
        )

        let snapshot = TimelineEngine().makeSnapshot(
            items: [allDayInterview],
            now: now,
            settings: .init(),
            staleInterval: 900
        )

        #expect(snapshot.pinnedItemID == allDayInterview.id)
        #expect(snapshot.pinOrigin == .automatic)
    }

    @Test func nonEligibleKindsAloneDoNotProduceAutomaticPin() {
        let now = Date(timeIntervalSince1970: 1_000)
        let task = item("task", .task, 1_100, 1_200)
        let unknown = item("unknown", .unknown, 1_050, 1_150)

        let snapshot = TimelineEngine().makeSnapshot(
            items: [task, unknown],
            now: now,
            settings: .init(),
            staleInterval: 900
        )

        #expect(snapshot.pinnedItemID == nil)
        #expect(snapshot.pinOrigin == nil)
    }

    @Test func hiddenTravelKindsAreNotAutomaticallyPinnedAsTravel() {
        let now = Date(timeIntervalSince1970: 1_000)
        let flight = item("flight", .flight, 1_050, 1_150)
        let train = item("train", .train, 1_060, 1_160)
        let travel = item("travel", .travel, 1_070, 1_170)
        let meeting = item("meeting", .meeting, 1_200, 1_300)

        let snapshot = TimelineEngine().makeSnapshot(
            items: [meeting, travel, train, flight],
            now: now,
            settings: .init(showTravelEvents: false),
            staleInterval: 900
        )

        #expect(snapshot.pinnedItemID == meeting.id)
        #expect(snapshot.pinOrigin == .automatic)
    }

    @Test func sortsItemsAndSetsSnapshotMetadata() {
        let now = Date(timeIntervalSince1970: 1_000)
        let noEnd = item("No End", .task, 1_100, nil)
        let laterEnd = item("Later End", .task, 1_100, 1_300)
        let alpha = item("Alpha", .task, 1_100, 1_200)
        let beta = item("Beta", .task, 1_100, 1_200)
        let earlier = item("Earlier", .task, 1_050, 1_100)

        let snapshot = TimelineEngine().makeSnapshot(
            items: [noEnd, beta, laterEnd, earlier, alpha],
            now: now,
            settings: .init(),
            staleInterval: 900
        )

        #expect(snapshot.items.map(\.id) == [
            earlier.id,
            alpha.id,
            beta.id,
            laterEnd.id,
            noEnd.id
        ])
        #expect(snapshot.generatedAt == now)
        #expect(snapshot.staleAfter == Date(timeIntervalSince1970: 1_900))
        #expect(snapshot.schemaVersion == TodaySnapshot.currentSchemaVersion)
        #expect(snapshot.pinnedItemID == nil)
        #expect(snapshot.pinOrigin == nil)
    }
}

private func item(
    _ title: String,
    _ kind: TimelineKind,
    _ start: TimeInterval,
    _ end: TimeInterval?,
    isAllDay: Bool = false,
    source: TimelineSource = .calendar
) -> TimelineItem {
    TimelineItem(
        id: "\(source.rawValue):\(title)",
        sourceIdentifier: title,
        title: title,
        startDate: Date(timeIntervalSince1970: start),
        endDate: end.map(Date.init(timeIntervalSince1970:)),
        isAllDay: isAllDay,
        source: source,
        kind: kind,
        location: nil,
        notes: nil
    )
}
