import SwiftUI
import UIKit
import Observation
import PeckerCore

enum SourcePermissionAction: Equatable {
    case requestAccess
    case openSettings
}

@MainActor
@Observable
final class SettingsViewModel {
    let settingsStore: SettingsStore
    private(set) var authorization: SourceAuthorization
    private(set) var permissionErrorText: String?
    private(set) var isRequestingPermission = false

    private let gateway: (any EventKitGatewayProtocol)?
    private let apiKeyStore: any APIKeyStoring
    private let notificationScheduler: any TimelineNotificationScheduling
    private let liveActivityStatusProvider: @MainActor () -> String
    private let onSettingsChanged: @MainActor () -> Void
    private let openURL: (URL) -> Void

    init(
        settingsStore: SettingsStore,
        gateway: (any EventKitGatewayProtocol)?,
        authorization: SourceAuthorization,
        apiKeyStore: any APIKeyStoring = KeychainAPIKeyStore(),
        notificationScheduler: any TimelineNotificationScheduling = UserNotificationScheduler(),
        liveActivityStatusText: @escaping @MainActor () -> String = {
            "waiting"
        },
        onSettingsChanged: @escaping @MainActor () -> Void,
        openURL: @escaping (URL) -> Void
    ) {
        self.settingsStore = settingsStore
        self.gateway = gateway
        self.authorization = authorization
        self.apiKeyStore = apiKeyStore
        self.notificationScheduler = notificationScheduler
        liveActivityStatusProvider = liveActivityStatusText
        self.onSettingsChanged = onSettingsChanged
        self.openURL = openURL
    }

    convenience init(
        settingsStore: SettingsStore,
        authorization: SourceAuthorization,
        apiKeyStore: any APIKeyStoring = KeychainAPIKeyStore(),
        notificationScheduler: any TimelineNotificationScheduling = UserNotificationScheduler(),
        liveActivityStatusText: @escaping @MainActor () -> String = {
            "waiting"
        },
        onSettingsChanged: @escaping @MainActor () -> Void,
        openURL: @escaping (URL) -> Void
    ) {
        self.init(
            settingsStore: settingsStore,
            gateway: nil,
            authorization: authorization,
            apiKeyStore: apiKeyStore,
            notificationScheduler: notificationScheduler,
            liveActivityStatusText: liveActivityStatusText,
            onSettingsChanged: onSettingsChanged,
            openURL: openURL
        )
    }

    func permissionAction(
        for source: TimelineSource
    ) -> SourcePermissionAction? {
        switch sourceStatus(for: source) {
        case .notDetermined:
            .requestAccess
        case .denied, .restricted, .writeOnly:
            .openSettings
        case .fullAccess:
            nil
        }
    }

    func permissionActionTitle(
        for source: TimelineSource,
        localizer: AppLocalizer
    ) -> String? {
        switch permissionAction(for: source) {
        case .requestAccess:
            localizer.string("settings.permission.allow")
        case .openSettings:
            localizer.string("settings.permission.openSettings")
        case nil:
            nil
        }
    }

    func refreshAuthorization() async {
        guard let gateway else { return }
        authorization = await gateway.authorization()
    }

    func performPermissionAction(
        for source: TimelineSource,
        localizer: AppLocalizer
    ) async {
        permissionErrorText = nil

        switch permissionAction(for: source) {
        case .requestAccess:
            guard let gateway else { return }
            isRequestingPermission = true
            defer { isRequestingPermission = false }

            do {
                switch source {
                case .calendar:
                    _ = try await gateway.requestCalendarAccess()
                case .reminder:
                    _ = try await gateway.requestReminderAccess()
                case .external:
                    return
                }
                authorization = await gateway.authorization()
                notifySettingsChanged()
            } catch {
                permissionErrorText = localizer.string(
                    source == .calendar
                        ? "settings.permission.calendar.error"
                        : "settings.permission.reminders.error"
                )
            }
        case .openSettings:
            openURL(URL(string: UIApplication.openSettingsURLString)!)
        case nil:
            break
        }
    }

    func clearPermissionError() {
        permissionErrorText = nil
    }

    func openAIAPIKeyStatusText(localizer: AppLocalizer) -> String {
        settingsStore.value.openAIAPIKeyConfigured
            ? localizer.string("settings.apiKey.configured")
            : localizer.string("settings.apiKey.notConfigured")
    }

    func liveActivityStatusText(localizer: AppLocalizer) -> String {
        guard settingsStore.value.liveActivityEnabled else {
            return localizer.string("settings.liveActivity.status.paused")
        }

        let status = liveActivityStatusProvider().lowercased()
        if status.contains("running") {
            return localizer.string("settings.liveActivity.status.running")
        }
        if status.contains("unavailable") {
            return localizer.string("settings.liveActivity.status.unavailable")
        }
        return localizer.string("settings.liveActivity.status.waiting")
    }

    func liveActivityDescriptionText(localizer: AppLocalizer) -> String {
        guard settingsStore.value.liveActivityEnabled else {
            return localizer.string("settings.liveActivity.description.paused")
        }
        let status = liveActivityStatusProvider().lowercased()
        if status.contains("running") {
            return localizer.string("settings.liveActivity.description.running")
        }
        if status.contains("unavailable") {
            return localizer.string("settings.liveActivity.description.unavailable")
        }
        return localizer.string("settings.liveActivity.description.waiting")
    }

    func sourceStatus(for source: TimelineSource) -> SourceAuthorizationStatus {
        switch source {
        case .calendar:
            authorization.calendar
        case .reminder:
            authorization.reminders
        case .external:
            .fullAccess
        }
    }

    func sourceStatusText(
        for source: TimelineSource,
        localizer: AppLocalizer
    ) -> String {
        switch sourceStatus(for: source) {
        case .fullAccess:
            return localizer.string("settings.source.status.authorized")
        case .notDetermined:
            return localizer.string("settings.source.status.notRequested")
        case .denied:
            return localizer.string("settings.source.status.denied")
        case .restricted:
            return localizer.string("settings.source.status.restricted")
        case .writeOnly:
            return localizer.string("settings.source.status.writeOnly")
        }
    }

    func sourceStatusDescription(
        for source: TimelineSource,
        localizer: AppLocalizer
    ) -> String {
        switch source {
        case .calendar:
            return localizer.string("settings.source.calendar.description")
        case .reminder:
            return localizer.string("settings.source.reminders.description")
        case .external:
            return localizer.string("settings.source.external.description")
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

    func setLiveActivityEnabled(_ enabled: Bool) {
        settingsStore.update { $0.liveActivityEnabled = enabled }
        notifySettingsChanged()
    }

    func setNotificationsEnabled(
        _ enabled: Bool,
        localizer: AppLocalizer
    ) async {
        permissionErrorText = nil
        if enabled {
            do {
                let granted = try await notificationScheduler.requestAuthorization()
                guard granted else {
                    settingsStore.update { $0.notificationsEnabled = false }
                    permissionErrorText = localizer.string(
                        "settings.notifications.error"
                    )
                    return
                }
                settingsStore.update { $0.notificationsEnabled = true }
                notifySettingsChanged()
            } catch {
                settingsStore.update { $0.notificationsEnabled = false }
                permissionErrorText = localizer.string(
                    "settings.notifications.error"
                )
            }
        } else {
            settingsStore.update { $0.notificationsEnabled = false }
            await notificationScheduler.cancelPendingTimelineNotifications()
            notifySettingsChanged()
        }
    }

    func setNotificationLeadTime(_ leadTime: TimelineNotificationLeadTime) {
        settingsStore.update { $0.notificationLeadTime = leadTime }
        notifySettingsChanged()
    }

    func setLanguage(_ language: AppLanguage) {
        settingsStore.update { $0.language = language }
        notifySettingsChanged()
    }

    func setAIRecognitionMode(_ mode: AIRecognitionMode) {
        settingsStore.update { $0.aiRecognitionMode = mode }
        notifySettingsChanged()
    }

    func setOpenAIHost(_ host: String) {
        settingsStore.update {
            $0.openAIHost = host.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        notifySettingsChanged()
    }

    func setOpenAIModel(_ model: String) {
        settingsStore.update {
            $0.openAIModel = model.trimmingCharacters(in: .whitespacesAndNewlines)
        }
        notifySettingsChanged()
    }

    func setSyncCalendarToStorage(_ enabled: Bool) {
        settingsStore.update { $0.syncCalendarToStorage = enabled }
        notifySettingsChanged()
    }

    func setSyncRemindersToStorage(_ enabled: Bool) {
        settingsStore.update { $0.syncRemindersToStorage = enabled }
        notifySettingsChanged()
    }

    func saveOpenAIAPIKey(_ key: String) throws {
        let trimmedKey = key.trimmingCharacters(in: .whitespacesAndNewlines)
        try apiKeyStore.saveOpenAIAPIKey(trimmedKey)
        settingsStore.update {
            $0.openAIAPIKeyConfigured = !trimmedKey.isEmpty
        }
        notifySettingsChanged()
    }

    func clearOpenAIAPIKey() throws {
        try apiKeyStore.clearOpenAIAPIKey()
        settingsStore.update { $0.openAIAPIKeyConfigured = false }
        notifySettingsChanged()
    }

    func reconcileAPIKeyStatus() {
        let configured =
            (try? apiKeyStore.loadOpenAIAPIKey())?
            .trimmingCharacters(in: .whitespacesAndNewlines)
            .isEmpty == false
        if settingsStore.value.openAIAPIKeyConfigured != configured {
            settingsStore.update {
                $0.openAIAPIKeyConfigured = configured
            }
        }
    }

    func openSourceSettings(for source: TimelineSource) {
        guard permissionAction(for: source) == .openSettings else {
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
    @Environment(\.dynamicTypeSize) private var dynamicTypeSize
    @Environment(\.scenePhase) private var scenePhase
    @Bindable var settingsStore: SettingsStore
    let viewModel: SettingsViewModel
    @State private var apiKeyDraft = ""
    @State private var apiKeyErrorText: String?
    @State private var hostDraft = ""
    @State private var hostErrorText: String?

    private var localizer: AppLocalizer {
        AppLocalizer(language: settingsStore.value.language)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    generalSection
                    notificationsSection
                    dataSourcesSection
                    recognitionSection
                    storageSection
                    liveActivitySection
                }
                .frame(maxWidth: 760, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .navigationTitle(localizer.string("settings.title"))
            .navigationBarTitleDisplayMode(.inline)
            .background(TimelineTheme.backgroundGradient.ignoresSafeArea())
            .foregroundStyle(TimelineTheme.textPrimary)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(localizer.string("settings.done")) {
                        dismiss()
                    }
                }
            }
        }
        .task {
            viewModel.reconcileAPIKeyStatus()
            hostDraft = settingsStore.value.openAIHost
            await viewModel.refreshAuthorization()
        }
        .onChange(of: scenePhase) { _, phase in
            guard phase == .active else { return }
            Task {
                await viewModel.refreshAuthorization()
            }
        }
        .alert(
            localizer.string("operation.failed"),
            isPresented: Binding(
                get: { viewModel.permissionErrorText != nil },
                set: { if !$0 { viewModel.clearPermissionError() } }
            )
        ) {
            Button(localizer.string("common.ok")) {
                viewModel.clearPermissionError()
            }
        } message: {
            if let message = viewModel.permissionErrorText {
                Text(message)
            }
        }
    }

    private var generalSection: some View {
        settingsSection(
            title: localizer.string("settings.general.title"),
            systemImage: "slider.horizontal.3",
            accent: .neutral
        ) {
            settingRow(
                title: localizer.string("settings.language"),
                systemImage: "globe",
                accent: .neutral
            ) {
                Picker(
                    localizer.string("settings.language"),
                    selection: Binding(
                        get: { settingsStore.value.language },
                        set: { viewModel.setLanguage($0) }
                    )
                ) {
                    ForEach(AppLanguage.allCases, id: \.self) { language in
                        Text(localizer.string(language.localizationKey))
                            .tag(language)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
            }

            rowDivider

            toggleRow(
                title: localizer.string("settings.timeline.showTravelEvents"),
                systemImage: "suitcase.fill",
                accent: .neutral,
                isOn: Binding(
                    get: { settingsStore.value.showTravelEvents },
                    set: { viewModel.setShowTravelEvents($0) }
                )
            )
        }
    }

    private var dataSourcesSection: some View {
        settingsSection(
            title: localizer.string("settings.dataSources.title"),
            systemImage: "tray.2.fill",
            accent: .next
        ) {
            sourceRow(
                title: localizer.string("source.calendar"),
                source: .calendar,
                systemImage: "calendar",
                accent: .next,
                toggleAction: viewModel.setCalendarEnabled(_:)
            )

            rowDivider

            sourceRow(
                title: localizer.string("source.reminders"),
                source: .reminder,
                systemImage: "checklist",
                accent: .next,
                toggleAction: viewModel.setRemindersEnabled(_:)
            )
        }
    }

    private var notificationsSection: some View {
        settingsSection(
            title: localizer.string("settings.notifications.title"),
            systemImage: "bell.badge.fill",
            accent: .now
        ) {
            toggleRow(
                title: localizer.string("settings.notifications.toggle"),
                detail: localizer.string("settings.notifications.description"),
                systemImage: "bell.fill",
                accent: .now,
                isOn: Binding(
                    get: { settingsStore.value.notificationsEnabled },
                    set: { enabled in
                        Task {
                            await viewModel.setNotificationsEnabled(
                                enabled,
                                localizer: localizer
                            )
                        }
                    }
                )
            )

            rowDivider

            settingRow(
                title: localizer.string("settings.notifications.leadTime"),
                systemImage: "timer",
                accent: .now
            ) {
                Picker(
                    localizer.string("settings.notifications.leadTime"),
                    selection: Binding(
                        get: { settingsStore.value.notificationLeadTime },
                        set: { viewModel.setNotificationLeadTime($0) }
                    )
                ) {
                    ForEach(TimelineNotificationLeadTime.allCases, id: \.self) { leadTime in
                        Text(label(for: leadTime)).tag(leadTime)
                    }
                }
                .labelsHidden()
                .pickerStyle(.menu)
                .disabled(!settingsStore.value.notificationsEnabled)
            }
        }
    }

    private var recognitionSection: some View {
        settingsSection(
            title: localizer.string("settings.ai.title"),
            systemImage: "sparkles",
            accent: .now
        ) {
            VStack(alignment: .leading, spacing: 12) {
                Picker(
                    localizer.string("settings.ai.mode"),
                    selection: Binding(
                        get: { settingsStore.value.aiRecognitionMode },
                        set: { viewModel.setAIRecognitionMode($0) }
                    )
                ) {
                    ForEach(AIRecognitionMode.allCases, id: \.self) { mode in
                        Text(label(for: mode)).tag(mode)
                    }
                }
                .pickerStyle(.segmented)

                switch settingsStore.value.aiRecognitionMode {
                case .off:
                    Text(localizer.string("settings.ai.offDescription"))
                        .font(.caption)
                        .foregroundStyle(TimelineTheme.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                case .openAI:
                    openAIConfiguration
                }
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
    }

    private var storageSection: some View {
        settingsSection(
            title: localizer.string("settings.storage.title"),
            systemImage: "externaldrive.fill",
            accent: .pinned
        ) {
            toggleRow(
                title: localizer.string("settings.storage.calendarCopy"),
                systemImage: "calendar.badge.plus",
                accent: .pinned,
                isOn: Binding(
                    get: { settingsStore.value.syncCalendarToStorage },
                    set: { viewModel.setSyncCalendarToStorage($0) }
                )
            )

            rowDivider

            toggleRow(
                title: localizer.string("settings.storage.remindersCopy"),
                systemImage: "checklist.checked",
                accent: .pinned,
                isOn: Binding(
                    get: { settingsStore.value.syncRemindersToStorage },
                    set: { viewModel.setSyncRemindersToStorage($0) }
                )
            )

            Text(localizer.string("settings.storage.description"))
                .font(.caption)
                .foregroundStyle(TimelineTheme.textTertiary)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.horizontal, 12)
                .padding(.bottom, 10)
        }
    }

    private var openAIConfiguration: some View {
        VStack(alignment: .leading, spacing: 0) {
            settingsTextFieldRow(
                title: localizer.string("settings.ai.host"),
                placeholder: "https://api.openai.com",
                text: $hostDraft,
                keyboardType: .URL
            )

            HStack(spacing: 10) {
                Button(localizer.string("common.save")) {
                    saveOpenAIHost()
                }
                .buttonStyle(
                    SettingsPillButtonStyle(
                        accent: TimelineTheme.now,
                        filled: true
                    )
                )
                Spacer(minLength: 8)
                if let hostErrorText {
                    Text(hostErrorText)
                        .font(.caption)
                        .foregroundStyle(TimelineTheme.now)
                }
            }
            .padding(.horizontal, 12)
            .padding(.bottom, 10)

            rowDivider

            settingsTextFieldRow(
                title: localizer.string("settings.ai.model"),
                placeholder: "gpt-5.4-mini",
                text: Binding(
                    get: { settingsStore.value.openAIModel },
                    set: { viewModel.setOpenAIModel($0) }
                ),
                keyboardType: .default
            )

            rowDivider

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .center, spacing: 12) {
                    rowIcon("key.fill", accent: .now)
                    Text(localizer.string("settings.apiKey.title"))
                        .font(.subheadline.weight(.semibold))
                    Spacer(minLength: 8)
                    statusBadge(viewModel.openAIAPIKeyStatusText(localizer: localizer))
                }

                SecureField("sk-...", text: $apiKeyDraft)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .font(.body.monospaced())
                    .foregroundStyle(TimelineTheme.textPrimary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 12)
                    .background(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .fill(TimelineTheme.controlFill)
                    )
                    .overlay(
                        RoundedRectangle(cornerRadius: 14, style: .continuous)
                            .stroke(TimelineTheme.cardStroke, lineWidth: 1)
                    )

                HStack(spacing: 10) {
                    Button(localizer.string("common.save")) {
                        saveOpenAIAPIKey()
                    }
                    .buttonStyle(SettingsPillButtonStyle(accent: TimelineTheme.now, filled: true))
                    .disabled(
                        apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                            .isEmpty
                    )

                    Button(localizer.string("common.clear")) {
                        clearOpenAIAPIKey()
                    }
                    .buttonStyle(SettingsPillButtonStyle(accent: TimelineTheme.textPrimary, filled: false))

                    Spacer(minLength: 8)
                }

                if let apiKeyErrorText {
                    Text(apiKeyErrorText)
                        .font(.caption)
                        .foregroundStyle(TimelineTheme.now)
                }

                Text(localizer.string("settings.apiKey.description"))
                    .font(.caption)
                    .foregroundStyle(TimelineTheme.textTertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
        }
        .background(nestedFill)
        .clipShape(RoundedRectangle(cornerRadius: 14, style: .continuous))
    }

    private func settingsTextFieldRow(
        title: String,
        placeholder: String,
        text: Binding<String>,
        keyboardType: UIKeyboardType
    ) -> some View {
        HStack(alignment: .center, spacing: 14) {
            rowIcon(
                title == localizer.string("settings.ai.host")
                    ? "network"
                    : "cpu",
                accent: .now
            )

            Text(title)
                .font(.subheadline.weight(.semibold))
                .frame(width: 68, alignment: .leading)

            TextField(placeholder, text: text)
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(keyboardType)
                .font(.body)
                .foregroundStyle(TimelineTheme.textPrimary)
                .multilineTextAlignment(.trailing)
                .padding(.vertical, 12)
        }
        .padding(.horizontal, 12)
    }

    private var liveActivitySection: some View {
        settingsSection(
            title: localizer.string("settings.liveActivity.title"),
            systemImage: "livephoto",
            accent: .pinned
        ) {
            VStack(alignment: .leading, spacing: 14) {
                HStack(alignment: .center, spacing: 12) {
                    rowIcon("iphone.radiowaves.left.and.right", accent: .pinned)

                    Text(localizer.string("settings.liveActivity.toggle"))
                        .font(.subheadline.weight(.semibold))

                    Spacer(minLength: 12)

                    Toggle(
                        localizer.string("settings.liveActivity.toggle"),
                        isOn: Binding(
                            get: { settingsStore.value.liveActivityEnabled },
                            set: { viewModel.setLiveActivityEnabled($0) }
                        )
                    )
                    .labelsHidden()
                }

                Text(viewModel.liveActivityDescriptionText(localizer: localizer))
                    .font(.caption)
                    .foregroundStyle(TimelineTheme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                    .padding(.leading, 52)

                HStack(alignment: .center, spacing: 12) {
                    rowIcon("waveform.path.ecg", accent: .pinned)

                    VStack(alignment: .leading, spacing: 3) {
                        Text(localizer.string("settings.liveActivity.statusLabel"))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(TimelineTheme.textSecondary)
                        statusBadge(viewModel.liveActivityStatusText(localizer: localizer))
                    }

                    Spacer(minLength: 0)
                }
                .padding(12)
                .background(nestedFill)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 12)
        }
    }

    private func sourceRow(
        title: String,
        source: TimelineSource,
        systemImage: String,
        accent: TimelineAccent,
        toggleAction: @escaping (Bool) -> Void
    ) -> some View {
        let status = viewModel.sourceStatusText(for: source, localizer: localizer)
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
        case .external:
            isEnabledBinding = .constant(true)
        }

        return Group {
            if dynamicTypeSize.isAccessibilitySize {
                VStack(alignment: .leading, spacing: 12) {
                    sourceLabel(
                        title: title,
                        status: status,
                        source: source,
                        systemImage: systemImage,
                        accent: accent
                    )
                    sourceControls(
                        title: title,
                        source: source,
                        status: status,
                        isEnabled: isEnabledBinding,
                        accent: accent
                    )
                    .frame(maxWidth: .infinity, alignment: .leading)
                }
            } else {
                HStack(alignment: .center, spacing: 12) {
                    sourceLabel(
                        title: title,
                        status: status,
                        source: source,
                        systemImage: systemImage,
                        accent: accent
                    )

                    Spacer(minLength: 8)

                    sourceControls(
                        title: title,
                        source: source,
                        status: status,
                        isEnabled: isEnabledBinding,
                        accent: accent
                    )
                }
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func sourceLabel(
        title: String,
        status: String,
        source: TimelineSource,
        systemImage: String,
        accent: TimelineAccent
    ) -> some View {
        HStack(alignment: .top, spacing: 12) {
            rowIcon(systemImage, accent: accent)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                Text(viewModel.sourceStatusDescription(for: source, localizer: localizer))
                    .font(.caption)
                    .foregroundStyle(TimelineTheme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
                if dynamicTypeSize.isAccessibilitySize {
                    Text(status)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(TimelineTheme.textSecondary)
                }
            }
        }
    }

    @ViewBuilder
    private func sourceControls(
        title: String,
        source: TimelineSource,
        status: String,
        isEnabled: Binding<Bool>,
        accent: TimelineAccent
    ) -> some View {
        HStack(spacing: 10) {
            if let actionTitle = viewModel.permissionActionTitle(
                for: source,
                localizer: localizer
            ) {
                Button(actionTitle) {
                    Task {
                        await viewModel.performPermissionAction(
                            for: source,
                            localizer: localizer
                        )
                    }
                }
                .buttonStyle(
                    SettingsPillButtonStyle(
                        accent: TimelineTheme.textColor(for: accent),
                        filled: false
                    )
                )
                .disabled(viewModel.isRequestingPermission)
            } else if !dynamicTypeSize.isAccessibilitySize {
                statusBadge(status)
            }

            Toggle(title, isOn: isEnabled)
                .labelsHidden()
                .accessibilityHint(
                    viewModel.sourceStatusDescription(
                        for: source,
                        localizer: localizer
                    )
                )
        }
    }

    private func toggleRow(
        title: String,
        detail: String? = nil,
        systemImage: String,
        accent: TimelineAccent,
        isOn: Binding<Bool>
    ) -> some View {
        settingRow(
            title: title,
            detail: detail,
            systemImage: systemImage,
            accent: accent
        ) {
            Toggle(title, isOn: isOn)
                .labelsHidden()
        }
    }

    private func settingRow<Trailing: View>(
        title: String,
        detail: String? = nil,
        systemImage: String,
        accent: TimelineAccent,
        @ViewBuilder trailing: () -> Trailing
    ) -> some View {
        HStack(alignment: .center, spacing: 12) {
            rowIcon(systemImage, accent: accent)

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                if let detail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(TimelineTheme.textTertiary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            Spacer(minLength: 8)
            trailing()
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    private func settingsSection<Content: View>(
        title: String,
        systemImage: String,
        accent: TimelineAccent,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            Label(title, systemImage: systemImage)
                .font(.footnote.weight(.bold))
                .foregroundStyle(TimelineTheme.textColor(for: accent))
                .textCase(.uppercase)
                .labelStyle(.titleAndIcon)
                .padding(.horizontal, 4)

            VStack(spacing: 0) {
                content()
            }
            .background(sectionFill)
            .clipShape(RoundedRectangle(cornerRadius: 18, style: .continuous))
            .overlay(
                RoundedRectangle(cornerRadius: 18, style: .continuous)
                    .stroke(TimelineTheme.cardStroke, lineWidth: 1)
            )
            .shadow(color: TimelineTheme.cardShadow.opacity(0.55), radius: 14, x: 0, y: 8)
        }
    }

    private var rowDivider: some View {
        Rectangle()
            .fill(TimelineTheme.cardStroke.opacity(0.82))
            .frame(height: 1)
            .padding(.leading, 52)
    }

    private var sectionFill: some ShapeStyle {
        TimelineTheme.cardWarmFill
    }

    private var nestedFill: some ShapeStyle {
        TimelineTheme.controlFill
    }

    private func rowIcon(
        _ systemImage: String,
        accent: TimelineAccent
    ) -> some View {
        Image(systemName: systemImage)
            .font(.system(size: 14, weight: .semibold))
            .foregroundStyle(TimelineTheme.color(for: accent))
            .frame(width: 28, height: 28)
            .background(
                RoundedRectangle(cornerRadius: 7, style: .continuous)
                    .fill(TimelineTheme.color(for: accent).opacity(0.12))
            )
    }

    private func statusBadge(_ text: String) -> some View {
        Text(text)
            .font(.caption.weight(.semibold))
            .foregroundStyle(TimelineTheme.textSecondary)
            .lineLimit(1)
            .padding(.horizontal, 9)
            .padding(.vertical, 4)
            .background(Capsule().fill(TimelineTheme.controlFill))
            .overlay(Capsule().stroke(TimelineTheme.cardStroke, lineWidth: 1))
    }

    private func label(for mode: AIRecognitionMode) -> String {
        switch mode {
        case .off:
            return localizer.string("settings.ai.mode.off")
        case .openAI:
            return "OpenAI"
        }
    }

    private func label(for leadTime: TimelineNotificationLeadTime) -> String {
        switch leadTime {
        case .atStart:
            return localizer.string("settings.notifications.leadTime.atStart")
        case .fiveMinutes:
            return localizer.string("settings.notifications.leadTime.five")
        case .tenMinutes:
            return localizer.string("settings.notifications.leadTime.ten")
        case .thirtyMinutes:
            return localizer.string("settings.notifications.leadTime.thirty")
        case .oneHour:
            return localizer.string("settings.notifications.leadTime.oneHour")
        }
    }

    private func saveOpenAIAPIKey() {
        do {
            try viewModel.saveOpenAIAPIKey(apiKeyDraft)
            apiKeyDraft = ""
            apiKeyErrorText = nil
        } catch {
            apiKeyErrorText = localizer.string("settings.apiKey.saveError")
        }
    }

    private func saveOpenAIHost() {
        do {
            let host = try RecognitionHostValidator.validate(hostDraft)
            viewModel.setOpenAIHost(host)
            hostDraft = host
            hostErrorText = nil
        } catch {
            hostErrorText = localizer.string("settings.host.invalid")
        }
    }

    private func clearOpenAIAPIKey() {
        do {
            try viewModel.clearOpenAIAPIKey()
            apiKeyDraft = ""
            apiKeyErrorText = nil
        } catch {
            apiKeyErrorText = localizer.string("settings.apiKey.clearError")
        }
    }

}

private struct SettingsPillButtonStyle: ButtonStyle {
    let accent: Color
    let filled: Bool

    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .font(.subheadline.weight(.semibold))
            .foregroundStyle(filled ? Color.white : accent)
            .padding(.horizontal, 16)
            .padding(.vertical, 9)
            .background(
                Capsule()
                    .fill(filled ? accent : TimelineTheme.controlFill)
            )
            .overlay(
                Capsule()
                    .stroke(filled ? Color.clear : TimelineTheme.cardStroke, lineWidth: 1)
            )
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

private extension AppLanguage {
    var localizationKey: String {
        switch self {
        case .system:
            "language.system"
        case .english:
            "language.english"
        case .simplifiedChinese:
            "language.simplifiedChinese"
        }
    }
}

private extension View {
    func settingsFormBackground() -> some View {
        background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(TimelineTheme.controlFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(TimelineTheme.cardStroke, lineWidth: 1)
        )
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
