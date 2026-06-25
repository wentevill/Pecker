import ActivityKit
import SwiftUI
import WidgetKit

struct PeckerLiveActivityWidget: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: PeckerActivityAttributes.self) { context in
            LockScreenLiveActivityView(context: context)
                .activityBackgroundTint(PeckerLiveActivityPalette.darkBottom.color)
                .activitySystemActionForegroundColor(PeckerLiveActivityPalette.textPrimary.color)
        } dynamicIsland: { context in
            DynamicIslandLiveActivityView(context: context).body
        }
    }
}
