import ActivityKit
import Foundation

enum ActivityDecision: Equatable, Sendable {
    case none
    case start(PeckerActivityAttributes.ContentState, Date)
    case update(PeckerActivityAttributes.ContentState, Date)
    case end
}

protocol ActivityClient: Sendable {
    func currentState() async -> PeckerActivityAttributes.ContentState?
    func apply(
        _ decision: ActivityDecision,
        attributes: PeckerActivityAttributes
    ) async throws
}

struct LiveActivityClient: ActivityClient {
    func currentState() async -> PeckerActivityAttributes.ContentState? {
        Activity<PeckerActivityAttributes>.activities.first?.content.state
    }

    func apply(
        _ decision: ActivityDecision,
        attributes: PeckerActivityAttributes
    ) async throws {
        switch decision {
        case .none:
            return
        case let .start(state, staleDate):
            _ = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: staleDate),
                pushType: nil
            )
        case let .update(state, staleDate):
            for activity in Activity<PeckerActivityAttributes>.activities {
                await activity.update(
                    ActivityContent(state: state, staleDate: staleDate)
                )
            }
        case .end:
            for activity in Activity<PeckerActivityAttributes>.activities {
                await activity.end(nil, dismissalPolicy: .immediate)
            }
        }
    }
}
