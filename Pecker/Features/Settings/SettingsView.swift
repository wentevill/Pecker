import SwiftUI
import UIKit
import PeckerCore

@MainActor
final class SettingsViewModel {
    let settingsStore: SettingsStore
    let authorization: SourceAuthorization

    private let apiKeyStore: any APIKeyStoring
    private let liveActivityStatusProvider: @MainActor () -> String
    private let onSettingsChanged: @MainActor () -> Void
    private let openURL: (URL) -> Void

    init(
        settingsStore: SettingsStore,
        authorization: SourceAuthorization,
        apiKeyStore: any APIKeyStoring = KeychainAPIKeyStore(),
        liveActivityStatusText: @escaping @MainActor () -> String = {
            "\u{7b49}\u{5f85}\u{5185}\u{5bb9}"
        },
        onSettingsChanged: @escaping @MainActor () -> Void,
        openURL: @escaping (URL) -> Void
    ) {
        self.settingsStore = settingsStore
        self.authorization = authorization
        self.apiKeyStore = apiKeyStore
        liveActivityStatusProvider = liveActivityStatusText
        self.onSettingsChanged = onSettingsChanged
        self.openURL = openURL
    }
    var openAIAPIKeyStatusText: String {
        settingsStore.value.openAIAPIKeyConfigured ? "\u{5df2}\u{914d}\u{7f6e}" : "\u{672a}\u{914d}\u{7f6e}"
    }

    var liveActivityStatusText: String {
        guard settingsStore.value.liveActivityEnabled else {
            return "\u{5df2}\u{6682}\u{505c}"
        }

        switch liveActivityStatusProvider() {
        case "\u{8fd0}\u{884c}\u{4e2d}":
            return "\u{8fd0}\u{884c}\u{4e2d}"
        case "\u{6682}\u{4e0d}\u{53ef}\u{7528}":
            return "\u{6682}\u{4e0d}\u{53ef}\u{7528}"
        default:
            return "\u{7b49}\u{5f85}\u{5185}\u{5bb9}"
        }
    }

    var liveActivityDescriptionText: String {
        switch liveActivityStatusText {
        case "\u{5df2}\u{6682}\u{505c}":
            return "\u{5df2}\u{6682}\u{505c}\u{9501}\u{5b9a}\u{5c4f}\u{5e55}\u{4e0e}\u{7075}\u{52a8}\u{5c9b}\u{663e}\u{793a}；\u{518d}\u{6b21}\u{5f00}\u{542f}\u{540e}\u{4f1a}\u{5728}\u{4e0b}\u{6b21}\u{5237}\u{65b0}\u{65f6}\u{6062}\u{590d}。"
        case "\u{8fd0}\u{884c}\u{4e2d}":
            return "\u{9501}\u{5b9a}\u{5c4f}\u{5e55}\u{4e0e}\u{7075}\u{52a8}\u{5c9b}\u{4f1a}\u{8ddf}\u{968f}\u{65f6}\u{95f4}\u{7ebf}\u{5237}\u{65b0}\u{66f4}\u{65b0}。"
        case "\u{6682}\u{4e0d}\u{53ef}\u{7528}":
            return "\u{7cfb}\u{7edf}\u{6682}\u{65f6}\u{65e0}\u{6cd5}\u{66f4}\u{65b0} Live Activity；\u{65f6}\u{95f4}\u{7ebf}\u{4ecd}\u{4f1a}\u{6b63}\u{5e38}\u{663e}\u{793a}。"
        default:
            return "\u{5f00}\u{542f}\u{540e}，\u{5237}\u{65b0}\u{51fa}\u{5f53}\u{524d}\u{5b89}\u{6392}\u{65f6}\u{4f1a}\u{663e}\u{793a}\u{5728}\u{9501}\u{5b9a}\u{5c4f}\u{5e55}\u{4e0e}\u{7075}\u{52a8}\u{5c9b}。"
        }
    }

    func sourceStatusText(for source: TimelineSource) -> String {
        let status: SourceAuthorizationStatus
        switch source {
        case .calendar:
            status = authorization.calendar
        case .reminder:
            status = authorization.reminders
        case .external:
            status = .fullAccess
        }

        switch status {
        case .fullAccess:
            return "\u{5df2}\u{6388}\u{6743}"
        case .notDetermined:
            return "\u{672a}\u{8bf7}\u{6c42}"
        case .denied:
            return "\u{5df2}\u{62d2}\u{7edd}"
        case .restricted:
            return "\u{53d7}\u{9650}"
        case .writeOnly:
            return "\u{4ec5}\u{5199}\u{5165}"
        }
    }

    func sourceStatusDescription(for source: TimelineSource) -> String {
        switch source {
        case .calendar:
            return "\u{8fc7}\u{6ee4}\u{7ed3}\u{679c}\u{4e0d}\u{4f1a}\u{6539}\u{53d8}\u{7cfb}\u{7edf}\u{6743}\u{9650}。"
        case .reminder:
            return "\u{63d0}\u{9192}\u{4e8b}\u{9879}\u{6743}\u{9650}\u{4ec5}\u{5f71}\u{54cd}\u{63d0}\u{9192}\u{6765}\u{6e90}。"
        case .external:
            return "\u{56fe}\u{7247}\u{548c}\u{76f8}\u{673a}\u{8bc6}\u{522b}\u{4fdd}\u{5b58}\u{5728} Pecker \u{81ea}\u{5efa}\u{5b58}\u{50a8}。"
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

    func openSourceSettings(for source: TimelineSource) {
        let status: SourceAuthorizationStatus
        switch source {
        case .calendar:
            status = authorization.calendar
        case .reminder:
            status = authorization.reminders
        case .external:
            status = .fullAccess
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
    @State private var apiKeyDraft = ""
    @State private var apiKeyErrorText: String?

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 14) {
                    header
                    dataSourcesCard
                    timelineCard
                    aiRecognitionCard
                    liveActivityCard
                }
                .frame(maxWidth: 760, alignment: .leading)
                .padding(.horizontal, 16)
                .padding(.vertical, 14)
            }
            .navigationTitle("\u{8bbe}\u{7f6e}")
            .navigationBarTitleDisplayMode(.inline)
            .background(TimelineTheme.backgroundGradient.ignoresSafeArea())
            .foregroundStyle(TimelineTheme.textPrimary)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("\u{5b8c}\u{6210}") {
                        dismiss()
                    }
                }
            }
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("\u{8bbe}\u{7f6e}")
                .font(.largeTitle.weight(.bold))
            Text("\u{63a7}\u{5236}\u{6570}\u{636e}\u{6e90}、\u{663e}\u{793a}\u{504f}\u{597d}、AI \u{8bc6}\u{522b}\u{548c} Live Activity \u{72b6}\u{6001}。")
                .font(.subheadline)
                .foregroundStyle(TimelineTheme.textSecondary)
        }
    }

    private var dataSourcesCard: some View {
        TimelineCard(accent: .neutral) {
            VStack(alignment: .leading, spacing: 14) {
                Text("\u{6570}\u{636e}\u{6e90}")
                    .font(.headline.weight(.semibold))

                sourceRow(
                    title: "\u{65e5}\u{5386}",
                    source: .calendar,
                    toggleAction: viewModel.setCalendarEnabled(_:)
                )

                sourceRow(
                    title: "\u{63d0}\u{9192}\u{4e8b}\u{9879}",
                    source: .reminder,
                    toggleAction: viewModel.setRemindersEnabled(_:)
                )
            }
        }
    }

    private var timelineCard: some View {
        let localizer = AppLocalizer(language: settingsStore.value.language)
        TimelineCard(accent: .next) {
            VStack(alignment: .leading, spacing: 14) {
                Text("\u{65f6}\u{95f4}\u{7ebf}")
                    .font(.headline.weight(.semibold))

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
                .pickerStyle(.menu)

                Toggle(
                    "\u{663e}\u{793a}\u{65c5}\u{884c}\u{4e8b}\u{4ef6}",
                    isOn: Binding(
                        get: { settingsStore.value.showTravelEvents },
                        set: { viewModel.setShowTravelEvents($0) }
                    )
                )
            }
        }
    }

    private var aiRecognitionCard: some View {
        TimelineCard(accent: .now) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI \u{8bc6}\u{522b}")
                        .font(.headline.weight(.semibold))
                    Text("\u{4ece}\u{65e5}\u{5386}、\u{63d0}\u{9192}\u{4e8b}\u{9879}、\u{56fe}\u{7247}\u{6216}\u{76f8}\u{673a}\u{5185}\u{5bb9}\u{8bc6}\u{522b}\u{7ed3}\u{6784}\u{5316}\u{4e8b}\u{4ef6}。")
                        .font(.subheadline)
                        .foregroundStyle(TimelineTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Picker(
                    "\u{8bc6}\u{522b}\u{6a21}\u{5f0f}",
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
                    Text("\u{5173}\u{95ed}\u{540e}\u{4e0d}\u{4f1a}\u{5411}\u{5916}\u{90e8}\u{6a21}\u{578b}\u{53d1}\u{9001}\u{5185}\u{5bb9}；\u{672c}\u{5730}\u{5b58}\u{50a8}\u{540c}\u{6b65}\u{4ecd}\u{7531}\u{4e0b}\u{65b9}\u{5f00}\u{5173}\u{63a7}\u{5236}。")
                        .font(.subheadline)
                        .foregroundStyle(TimelineTheme.textSecondary)
                case .openAI:
                    openAIConfiguration
                }

                Divider()
                    .overlay(TimelineTheme.cardStroke)

                Toggle(
                    "\u{540c}\u{6b65}\u{65e5}\u{5386}\u{5230}\u{672c}\u{5730}\u{4e8b}\u{4ef6}\u{5b58}\u{50a8}",
                    isOn: Binding(
                        get: { settingsStore.value.syncCalendarToStorage },
                        set: { viewModel.setSyncCalendarToStorage($0) }
                    )
                )
                Toggle(
                    "\u{540c}\u{6b65}\u{63d0}\u{9192}\u{4e8b}\u{9879}\u{5230}\u{672c}\u{5730}\u{4e8b}\u{4ef6}\u{5b58}\u{50a8}",
                    isOn: Binding(
                        get: { settingsStore.value.syncRemindersToStorage },
                        set: { viewModel.setSyncRemindersToStorage($0) }
                    )
                )

                Text("\u{540c}\u{6b65}\u{5f00}\u{5173}\u{53ea}\u{51b3}\u{5b9a}\u{662f}\u{5426}\u{628a}\u{7cfb}\u{7edf}\u{6765}\u{6e90}\u{590d}\u{5236}\u{8fdb} Pecker \u{81ea}\u{5efa}\u{5b58}\u{50a8}；\u{4e0d}\u{4f1a}\u{4fee}\u{6539}\u{539f}\u{59cb}\u{65e5}\u{5386}\u{6216}\u{63d0}\u{9192}\u{4e8b}\u{9879}。")
                    .font(.caption)
                    .foregroundStyle(TimelineTheme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }

    private var openAIConfiguration: some View {
        VStack(alignment: .leading, spacing: 14) {
            VStack(spacing: 0) {
                settingsTextFieldRow(
                    title: "Host",
                    placeholder: "https://api.openai.com",
                    text: Binding(
                        get: { settingsStore.value.openAIHost },
                        set: { viewModel.setOpenAIHost($0) }
                    ),
                    keyboardType: .URL
                )

                formDivider

                settingsTextFieldRow(
                    title: "Model",
                    placeholder: "gpt-5.4-mini",
                    text: Binding(
                        get: { settingsStore.value.openAIModel },
                        set: { viewModel.setOpenAIModel($0) }
                    ),
                    keyboardType: .default
                )
            }
            .settingsFormBackground()

            VStack(alignment: .leading, spacing: 10) {
                HStack(alignment: .firstTextBaseline) {
                    Text("API Key")
                        .font(.subheadline.weight(.semibold))

                    Spacer(minLength: 8)

                    Text(viewModel.openAIAPIKeyStatusText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(TimelineTheme.textSecondary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(Capsule().fill(TimelineTheme.controlFill))
                        .overlay(Capsule().stroke(TimelineTheme.cardStroke, lineWidth: 1))
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
                    Button("\u{4fdd}\u{5b58}") {
                        saveOpenAIAPIKey()
                    }
                    .buttonStyle(SettingsPillButtonStyle(accent: TimelineTheme.now, filled: true))
                    .disabled(
                        apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                            .isEmpty
                    )

                    Button("\u{6e05}\u{9664}") {
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

                Text("API Key \u{4f1a}\u{4fdd}\u{5b58}\u{5230}\u{7cfb}\u{7edf} Keychain；\u{8bbe}\u{7f6e}\u{6587}\u{4ef6}\u{53ea}\u{8bb0}\u{5f55}\u{662f}\u{5426}\u{5df2}\u{914d}\u{7f6e}。")
                    .font(.caption)
                    .foregroundStyle(TimelineTheme.textTertiary)
            }
        }
    }

    private var formDivider: some View {
        Rectangle()
            .fill(TimelineTheme.cardStroke)
            .frame(height: 1)
            .padding(.leading, 92)
    }

    private func settingsTextFieldRow(
        title: String,
        placeholder: String,
        text: Binding<String>,
        keyboardType: UIKeyboardType
    ) -> some View {
        HStack(alignment: .center, spacing: 14) {
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

    private var liveActivityCard: some View {
        TimelineCard(accent: .pinned) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Live Activity")
                    .font(.headline.weight(.semibold))

                Toggle(
                    "\u{9501}\u{5b9a}\u{5c4f}\u{5e55}\u{4e0e}\u{7075}\u{52a8}\u{5c9b}",
                    isOn: Binding(
                        get: { settingsStore.value.liveActivityEnabled },
                        set: { viewModel.setLiveActivityEnabled($0) }
                    )
                )

                HStack {
                    Text("\u{72b6}\u{6001}")
                        .foregroundStyle(TimelineTheme.textSecondary)
                    Spacer(minLength: 8)
                    Text(viewModel.liveActivityStatusText)
                        .font(.subheadline.weight(.semibold))
                }

                Text(viewModel.liveActivityDescriptionText)
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
        let needsSettings = status == "\u{5df2}\u{62d2}\u{7edd}" || status == "\u{53d7}\u{9650}"
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

    private func label(for mode: AIRecognitionMode) -> String {
        switch mode {
        case .off:
            return "\u{5173}\u{95ed}"
        case .openAI:
            return "OpenAI"
        }
    }

    private func saveOpenAIAPIKey() {
        do {
            try viewModel.saveOpenAIAPIKey(apiKeyDraft)
            apiKeyDraft = ""
            apiKeyErrorText = nil
        } catch {
            apiKeyErrorText = "\u{4fdd}\u{5b58}\u{5931}\u{8d25}，\u{8bf7}\u{7a0d}\u{540e}\u{91cd}\u{8bd5}。"
        }
    }

    private func clearOpenAIAPIKey() {
        do {
            try viewModel.clearOpenAIAPIKey()
            apiKeyDraft = ""
            apiKeyErrorText = nil
        } catch {
            apiKeyErrorText = "\u{6e05}\u{9664}\u{5931}\u{8d25}，\u{8bf7}\u{7a0d}\u{540e}\u{91cd}\u{8bd5}。"
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
