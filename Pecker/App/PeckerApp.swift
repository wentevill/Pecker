import SwiftUI
import PeckerCore

enum AppIdentity {
    static let displayName = "Pecker"
}

@main
struct PeckerApp: App {
    @Environment(\.scenePhase) private var scenePhase
    private let root: AppRoot

    init() {
#if DEBUG
        let arguments = ProcessInfo.processInfo.arguments
        if arguments.contains("-previewTimeline") {
            root = .previewTimeline
            return
        }
        if arguments.contains("-previewDetail") {
            root = .previewDetail
            return
        }
        if arguments.contains("-previewSettings") {
            root = .previewSettings
            return
        }
        if arguments.contains("-previewToday") {
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
                "无法打开 Pecker 的共享 App Group（\(AppGroup.identifier)）。请检查签名与 entitlements 配置。"
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
    case previewTimeline
    case previewDetail
    case previewSettings
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
        case .previewTimeline:
            FullTimelinePreviewHost()
        case .previewDetail:
            ItemDetailPreviewHost()
        case .previewSettings:
            SettingsPreviewHost()
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
                TodayView(
                    model: model.todayViewModel,
                    settingsStore: model.dependencies.settingsStore,
                    onSettingsChanged: { @MainActor in
                        model.settingsChanged()
                    }
                )
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

#if DEBUG
private struct FullTimelinePreviewHost: View {
    private let previewNow = Date()
    private let settings: TimelineSettings

    init() {
        var settings = TimelineSettings()
        settings.manualPinnedSourceIdentifier = "upcoming"
        self.settings = settings
    }

    var body: some View {
        NavigationStack {
            FullTimelineView(
                snapshot: snapshot,
                now: previewNow,
                settings: settings,
                activeOnly: false,
                onSelectItem: { _ in },
                onTogglePin: { _ in },
                onOpenSettings: {}
            )
        }
    }

    private var snapshot: TodaySnapshot {
        TodaySnapshot(
            schemaVersion: TodaySnapshot.currentSchemaVersion,
            generatedAt: previewNow,
            staleAfter: previewNow.addingTimeInterval(30 * 60),
            items: [
                item(id: "overdue", title: "Overdue Reminder", start: previewNow.addingTimeInterval(-3 * 3_600), end: previewNow.addingTimeInterval(-2 * 3_600), source: .reminder, kind: .task),
                item(id: "all-day", title: "All-day conference", start: previewNow, end: previewNow.addingTimeInterval(24 * 3_600), source: .calendar, kind: .travel, isAllDay: true),
                item(id: "active", title: "Design review", start: previewNow.addingTimeInterval(-25 * 60), end: previewNow.addingTimeInterval(20 * 60), source: .calendar, kind: .meeting),
                item(id: "upcoming", title: "Flight to Singapore", start: previewNow.addingTimeInterval(2 * 3_600), end: previewNow.addingTimeInterval(4 * 3_600), source: .calendar, kind: .flight, location: "T3 · Gate B7"),
                item(id: "elapsed", title: "Morning standup", start: previewNow.addingTimeInterval(-8 * 3_600), end: previewNow.addingTimeInterval(-7 * 3_600), source: .calendar, kind: .meeting)
            ],
            nowItemID: "active",
            concurrentNowCount: 2,
            nextItemID: "upcoming",
            pinnedItemID: "upcoming",
            pinOrigin: .manual
        )
    }

    private func item(
        id: String,
        title: String,
        start: Date,
        end: Date,
        source: TimelineSource,
        kind: TimelineKind,
        location: String? = nil,
        isAllDay: Bool = false
    ) -> TimelineItem {
        TimelineItem(
            id: id,
            sourceIdentifier: id,
            title: title,
            startDate: start,
            endDate: end,
            isAllDay: isAllDay,
            source: source,
            kind: kind,
            location: location,
            notes: nil
        )
    }
}

private struct ItemDetailPreviewHost: View {
    private let settingsStore = SettingsStore(defaults: UserDefaults(suiteName: "preview.detail") ?? .standard)

    var body: some View {
        NavigationStack {
            ItemDetailView(
                item: TodayPreviewFixtures.flightItem(),
                now: TodayPreviewFixtures.makeSampleNow(),
                settingsStore: settingsStore,
                onSettingsChanged: {}
            )
        }
    }
}

private struct SettingsPreviewHost: View {
    private let settingsStore = SettingsStore(defaults: UserDefaults(suiteName: "preview.settings") ?? .standard)
    private let viewModel: SettingsViewModel

    init() {
        let store = settingsStore
        viewModel = SettingsViewModel(
            settingsStore: store,
            authorization: .init(calendar: .denied, reminders: .fullAccess),
            onSettingsChanged: {},
            openURL: { _ in }
        )
    }

    var body: some View {
        SettingsView(settingsStore: settingsStore, viewModel: viewModel)
    }
}
#endif

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
