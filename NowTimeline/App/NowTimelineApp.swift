import SwiftUI

enum AppIdentity {
    static let displayName = "Now Timeline"
}

@main
struct NowTimelineApp: App {
    @Environment(\.scenePhase) private var scenePhase
    private let root: AppRoot

    init() {
#if DEBUG
        if ProcessInfo.processInfo.arguments.contains("-previewToday") {
            root = .previewToday
            return
        }
#endif
        do {
            guard let defaults = UserDefaults(suiteName: AppGroup.identifier)
            else {
                throw SettingsStoreError.appGroupUnavailable
            }
            let settingsStore = SettingsStore(defaults: defaults)
            let dependencies = try AppDependencies.production(
                settingsStoreFactory: { settingsStore }
            )
            root = .ready(
                AppModel(
                    dependencies: dependencies,
                    onboardingDefaults: defaults
                )
            )
        } catch {
            root = .configurationFailure(
                "无法打开共享 App Group（\(AppGroup.identifier)）。请检查签名与 entitlements 配置。"
            )
        }
    }

    var body: some Scene {
        WindowGroup {
            AppRootView(root: root)
        }
        .onChange(of: scenePhase) { _, newPhase in
            guard case let .ready(model) = root else {
                return
            }
            switch newPhase {
            case .active:
                model.becameActive()
            case .inactive, .background:
                model.becameInactive()
            @unknown default:
                model.becameInactive()
            }
        }
    }
}

private enum AppRoot {
    case ready(AppModel)
#if DEBUG
    case previewToday
#endif
    case configurationFailure(String)
}

private struct AppRootView: View {
    let root: AppRoot

    var body: some View {
        switch root {
        case let .ready(model):
            ReadyRootView(model: model)
#if DEBUG
        case .previewToday:
            TodayPreviewHost()
#endif
        case let .configurationFailure(message):
            ConfigurationFailureView(message: message)
        }
    }
}

private struct ReadyRootView: View {
    @Bindable var model: AppModel

    var body: some View {
        Group {
            if model.onboardingCompleted {
                TodayView(model: model.todayViewModel)
            } else {
                OnboardingView(model: model.onboardingModel) {
                    model.start()
                }
            }
        }
        .task {
            if model.onboardingCompleted {
                model.start()
            }
        }
    }
}

private struct ConfigurationFailureView: View {
    let message: String

    var body: some View {
        ZStack {
            Color(red: 0.08, green: 0.025, blue: 0.04)
                .ignoresSafeArea()
            VStack(alignment: .leading, spacing: 16) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .font(.largeTitle)
                    .foregroundStyle(.orange)
                    .accessibilityHidden(true)
                Text("配置错误")
                    .font(.title.bold())
                Text(message)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.78))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .frame(maxWidth: 560, alignment: .leading)
            .padding(28)
            .foregroundStyle(.white)
        }
        .accessibilityElement(children: .combine)
    }
}
