import ActivityKit
import Foundation

enum ActivityDecision: Equatable, Sendable {
    case none
    case start(PeckerActivityAttributes.ContentState, Date)
    case update(PeckerActivityAttributes.ContentState, Date)
    case end
}

struct ActivityClientSnapshot: Equatable, Sendable {
    let id: String
    let localDayIdentifier: String
    let contentState: PeckerActivityAttributes.ContentState
}

enum ActivityClientOperation: Equatable {
    case start(
        state: PeckerActivityAttributes.ContentState,
        staleDate: Date,
        attributes: PeckerActivityAttributes
    )
    case update(
        id: String,
        state: PeckerActivityAttributes.ContentState,
        staleDate: Date
    )
    case end(id: String)

    static func == (
        left: ActivityClientOperation,
        right: ActivityClientOperation
    ) -> Bool {
        switch (left, right) {
        case let (
            .start(leftState, leftStaleDate, leftAttributes),
            .start(rightState, rightStaleDate, rightAttributes)
        ):
            return leftState == rightState
                && leftStaleDate == rightStaleDate
                && leftAttributes.localDayIdentifier
                    == rightAttributes.localDayIdentifier
        case let (
            .update(leftID, leftState, leftStaleDate),
            .update(rightID, rightState, rightStaleDate)
        ):
            return leftID == rightID
                && leftState == rightState
                && leftStaleDate == rightStaleDate
        case let (.end(leftID), .end(rightID)):
            return leftID == rightID
        case (.start, _), (.update, _), (.end, _):
            return false
        }
    }
}

protocol ActivityClient: Sendable {
    func activitySnapshots() async -> [ActivityClientSnapshot]
    func start(
        state: PeckerActivityAttributes.ContentState,
        staleDate: Date,
        attributes: PeckerActivityAttributes
    ) async throws
    func update(
        id: String,
        state: PeckerActivityAttributes.ContentState,
        staleDate: Date
    ) async
    func end(id: String) async
}

struct LiveActivityClient: ActivityClient {
    func activitySnapshots() async -> [ActivityClientSnapshot] {
        Activity<PeckerActivityAttributes>.activities.map { activity in
            ActivityClientSnapshot(
                id: activity.id,
                localDayIdentifier: activity.attributes.localDayIdentifier,
                contentState: activity.content.state
            )
        }
    }

    func start(
        state: PeckerActivityAttributes.ContentState,
        staleDate: Date,
        attributes: PeckerActivityAttributes
    ) async throws {
        _ = try Activity.request(
            attributes: attributes,
            content: ActivityContent(state: state, staleDate: staleDate),
            pushType: nil
        )
    }

    func update(
        id: String,
        state: PeckerActivityAttributes.ContentState,
        staleDate: Date
    ) async {
        guard let activity = Activity<PeckerActivityAttributes>.activities
            .first(where: { $0.id == id })
        else {
            return
        }

        await activity.update(
            ActivityContent(state: state, staleDate: staleDate)
        )
    }

    func end(id: String) async {
        guard let activity = Activity<PeckerActivityAttributes>.activities
            .first(where: { $0.id == id })
        else {
            return
        }

        await activity.end(nil, dismissalPolicy: .immediate)
    }
}
