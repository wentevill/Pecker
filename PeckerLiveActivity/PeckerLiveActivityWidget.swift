import ActivityKit
import SwiftUI
import WidgetKit

struct PeckerLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PeckerActivityAttributes.self) { context in
            LockScreenLiveActivityView(context: context)
                .activityBackgroundTint(Color.black.opacity(0.85))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            DynamicIsland {
                DynamicIslandExpandedRegion(.center) {
                    Text(context.state.primaryTitle)
                }
            } compactLeading: {
                Circle().fill(.green).frame(width: 8, height: 8)
            } compactTrailing: {
                Text("Now")
            } minimal: {
                Circle().fill(.green).frame(width: 8, height: 8)
            }
        }
    }
}
