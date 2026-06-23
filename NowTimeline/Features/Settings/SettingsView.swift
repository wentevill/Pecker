import SwiftUI
import UIKit
import NowTimelineCore

@MainActor
final class SettingsViewModel {
    let settingsStore: SettingsStore
    let authorization: SourceAuthorization

    private let onSettingsChanged: @MainActor () -> Void
    private let openURL: (URL) -> Void

    init(
        settingsStore: SettingsStore,
        authorization: SourceAuthorization,
        onSettingsChanged: @escaping @MainActor () -> Void,
        openURL: @escaping (URL) -> Void
    ) {
        self.settingsStore = settingsStore
        self.authorization = authorization
        self.onSettingsChanged = onSettingsChanged
        self.openURL = openURL
    }

    var liveActivityStatusText: String {
        settingsStore.value.liveActivityEnabled ? "等待接入" : "尚未启用"
    }

    func sourceStatusText(for source: TimelineSource) -> String {
        let status: SourceAuthorizationStatus
        switch source {
        case .calendar:
            status = authorization.calendar
        case .reminder:
            status = authorization.reminders
        }

        switch status {
        case .fullAccess:
            return "已授权"
        case .notDetermined:
            return "未请求"
        case .denied:
            return "已拒绝"
        case .restricted:
            return "受限"
        case .writeOnly:
            return "仅写入"
        }
    }

    func sourceStatusDescription(for source: TimelineSource) -> String {
        switch source {
        case .calendar:
            return "过滤结果不会改变系统权限。"
        case .reminder:
            return "提醒事项权限仅影响提醒来源。"
        }
    }

    func setCalendarEnabled(_ enabled: Bool) {
        settingsStore.update { $0.calendarEnabled = enabled }
        notifySettingsChanged()
    }

    func setRemindersEnabled(_ enabled: Bool) {
        settingsStore.update { $0.remindersEnabled = enabled }
        notifySettingsChanged()
    }

    func setShowTravelEvents(_ enabled: Bool) {
        settingsStore.update { $0.showTravelEvents = enabled }
        notifySettingsChanged()
    }

    func setReminderDurationMinutes(_ minutes: Int) {
        settingsStore.update { $0.reminderDurationMinutes = minutes }
        notifySettingsChanged()
    }

    func openSourceSettings(for source: TimelineSource) {
        let status: SourceAuthorizationStatus
        switch source {
        case .calendar:
            status = authorization.calendar
        case .reminder:
            status = authorization.reminders
        }

        guard status == .denied || status == .restricted else {
            return
        }

        openURL(URL(string: UIApplication.openSettingsURLString)!)
    }

    private func notifySettingsChanged() {
        onSettingsChanged()
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var settingsStore: SettingsStore
    let viewModel: SettingsViewModel

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    dataSourcesCard
                    timelineCard
                    liveActivityCard
                }
                .frame(maxWidth: 760, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .navigationTitle("设置")
            .navigationBarTitleDisplayMode(.inline)
            .background(TimelineTheme.backgroundGradient.ignoresSafeArea())
            .foregroundStyle(TimelineTheme.textPrimary)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("完成") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("设置")
                .font(.largeTitle.weight(.bold))
            Text("控制数据源、显示偏好和当前的 Live Activity 占位状态。")
                .font(.subheadline)
                .foregroundStyle(TimelineTheme.textSecondary)
        }
    }

    private var dataSourcesCard: some View {
        TimelineCard(accent: .neutral) {
            VStack(alignment: .leading, spacing: 14) {
                Text("数据源")
                    .font(.headline.weight(.semibold))

                sourceRow(
                    title: "日历",
                    source: .calendar,
                    toggleAction: viewModel.setCalendarEnabled(_:)
                )

                sourceRow(
                    title: "提醒事项",
                    source: .reminder,
                    toggleAction: viewModel.setRemindersEnabled(_:)
                )
            }
        }
    }

    private var timelineCard: some View {
        TimelineCard(accent: .next) {
            VStack(alignment: .leading, spacing: 14) {
                Text("时间线")
                    .font(.headline.weight(.semibold))

                Toggle(
                    "显示旅行事件",
                    isOn: Binding(
                        get: { settingsStore.value.showTravelEvents },
                        set: { viewModel.setShowTravelEvents($0) }
                    )
                )

                VStack(alignment: .leading, spacing: 10) {
                    Text("提醒持续时间")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(TimelineTheme.textSecondary)

                    Picker(
                        "提醒持续时间",
                        selection: Binding(
                            get: { settingsStore.value.reminderDurationMinutes },
                            set: { viewModel.setReminderDurationMinutes($0) }
                        )
                    ) {
                        ForEach([15, 30, 45, 60], id: \.self) { minutes in
                            Text("\(minutes) 分钟").tag(minutes)
                        }
                    }
                    .pickerStyle(.segmented)
                }
            }
        }
    }

    private var liveActivityCard: some View {
        TimelineCard(accent: .pinned) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Live Activity")
                    .font(.headline.weight(.semibold))

                HStack {
                    Text("状态")
                        .foregroundStyle(TimelineTheme.textSecondary)
                    Spacer(minLength: 8)
                    Text(viewModel.liveActivityStatusText)
                        .font(.subheadline.weight(.semibold))
                }

                Text("此版本仅展示偏好状态，尚未接入 ActivityKit。")
                    .font(.subheadline)
                    .foregroundStyle(TimelineTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private func sourceRow(
        title: String,
        source: TimelineSource,
        toggleAction: @escaping (Bool) -> Void
    ) -> some View {
        let status = viewModel.sourceStatusText(for: source)
        let needsSettings = status == "已拒绝" || status == "受限"
        let isEnabledBinding: Binding<Bool>
        switch source {
        case .calendar:
            isEnabledBinding = Binding(
                get: { settingsStore.value.calendarEnabled },
                set: { toggleAction($0) }
            )
        case .reminder:
            isEnabledBinding = Binding(
                get: { settingsStore.value.remindersEnabled },
                set: { toggleAction($0) }
            )
        }

        return VStack(alignment: .leading, spacing: 8) {
            HStack(alignment: .center, spacing: 12) {
                Toggle(
                    title,
                    isOn: isEnabledBinding
                )

                if needsSettings {
                    Button(status) {
                        viewModel.openSourceSettings(for: source)
                    }
                    .buttonStyle(.plain)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(TimelineTheme.next)
                } else {
                    Text(status)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(TimelineTheme.textSecondary)
                }
            }

            Text(viewModel.sourceStatusDescription(for: source))
                .font(.caption)
                .foregroundStyle(TimelineTheme.textTertiary)
            .fixedSize(horizontal: false, vertical: true)
        }
    }
}

#if DEBUG
private struct SettingsPreviewHost: View {
    private let store = SettingsStore(defaults: UserDefaults(suiteName: "preview.settings") ?? .standard)
    private let viewModel: SettingsViewModel

    init() {
        viewModel = SettingsViewModel(
            settingsStore: store,
            authorization: .init(calendar: .denied, reminders: .fullAccess),
            onSettingsChanged: {},
            openURL: { _ in }
        )
    }

    var body: some View {
        SettingsView(settingsStore: store, viewModel: viewModel)
    }
}

#Preview("Authorized") {
    SettingsPreviewHost()
}

#Preview("Denied") {
    SettingsPreviewHost()
        .dynamicTypeSize(.accessibility1)
}
#endif
