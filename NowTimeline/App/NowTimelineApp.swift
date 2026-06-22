import SwiftUI

enum AppIdentity {
    static let displayName = "Now Timeline"
}

@main
struct NowTimelineApp: App {
    var body: some Scene {
        WindowGroup {
            Text(AppIdentity.displayName)
        }
    }
}
