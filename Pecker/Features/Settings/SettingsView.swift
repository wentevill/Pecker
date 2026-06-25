import SwiftUI
import UIKit
import PhotosUI
import PeckerCore

@MainActor
final class SettingsViewModel {
    let settingsStore: SettingsStore
    let authorization: SourceAuthorization

    private let apiKeyStore: any APIKeyStoring
    private let imageRecognizer: any ImageRecognizing
    private let liveActivityStatusProvider: @MainActor () -> String
    private let onSettingsChanged: @MainActor () -> Void
    private let openURL: (URL) -> Void

    init(
        settingsStore: SettingsStore,
        authorization: SourceAuthorization,
        apiKeyStore: any APIKeyStoring = KeychainAPIKeyStore(),
        imageRecognizer: any ImageRecognizing = NoopImageRecognizer(),
        liveActivityStatusText: @escaping @MainActor () -> String = {
            "等待内容"
        },
        onSettingsChanged: @escaping @MainActor () -> Void,
        openURL: @escaping (URL) -> Void
    ) {
        self.settingsStore = settingsStore
        self.authorization = authorization
        self.apiKeyStore = apiKeyStore
        self.imageRecognizer = imageRecognizer
        liveActivityStatusProvider = liveActivityStatusText
        self.onSettingsChanged = onSettingsChanged
        self.openURL = openURL
    }

    private(set) var imageRecognitionStatusText = "等待图片"

    var openAIAPIKeyStatusText: String {
        settingsStore.value.openAIAPIKeyConfigured ? "已配置" : "未配置"
    }

    var liveActivityStatusText: String {
        guard settingsStore.value.liveActivityEnabled else {
            return "已暂停"
        }

        switch liveActivityStatusProvider() {
        case "运行中":
            return "运行中"
        case "暂不可用":
            return "暂不可用"
        default:
            return "等待内容"
        }
    }

    var liveActivityDescriptionText: String {
        switch liveActivityStatusText {
        case "已暂停":
            return "已暂停锁定屏幕与灵动岛显示；再次开启后会在下次刷新时恢复。"
        case "运行中":
            return "锁定屏幕与灵动岛会跟随时间线刷新更新。"
        case "暂不可用":
            return "系统暂时无法更新 Live Activity；时间线仍会正常显示。"
        default:
            return "开启后，刷新出当前安排时会显示在锁定屏幕与灵动岛。"
        }
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

    func setLiveActivityEnabled(_ enabled: Bool) {
        settingsStore.update { $0.liveActivityEnabled = enabled }
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

    func recognizeImportedImage(_ data: Data, filename: String?) async throws {
        try await recognizeImage(
            data,
            source: .importedImage,
            filename: filename,
            successText: "图片识别完成"
        )
    }

    func recognizeCameraImage(_ data: Data) async throws {
        try await recognizeImage(
            data,
            source: .cameraImage,
            filename: "camera.jpg",
            successText: "相机识别完成"
        )
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

    private func recognizeImage(
        _ data: Data,
        source: RecognitionSource,
        filename: String?,
        successText: String
    ) async throws {
        imageRecognitionStatusText = "识别中…"
        do {
            _ = try await imageRecognizer.recognizeImage(
                data: data,
                source: source,
                filename: filename,
                settings: settingsStore.value,
                now: .now
            )
            imageRecognitionStatusText = successText
            notifySettingsChanged()
        } catch {
            imageRecognitionStatusText = "识别失败"
            throw error
        }
    }
}

struct SettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @Bindable var settingsStore: SettingsStore
    let viewModel: SettingsViewModel
    @State private var apiKeyDraft = ""
    @State private var apiKeyErrorText: String?
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isCameraPresented = false
    @State private var imageRecognitionErrorText: String?

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
            Text("控制数据源、显示偏好、AI 识别和 Live Activity 状态。")
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
            }
        }
    }

    private var aiRecognitionCard: some View {
        TimelineCard(accent: .now) {
            VStack(alignment: .leading, spacing: 14) {
                VStack(alignment: .leading, spacing: 4) {
                    Text("AI 识别")
                        .font(.headline.weight(.semibold))
                    Text("从日历、提醒事项、图片或相机内容识别结构化事件。")
                        .font(.subheadline)
                        .foregroundStyle(TimelineTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Picker(
                    "识别模式",
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
                    Text("关闭后不会向外部模型发送内容；本地存储同步仍由下方开关控制。")
                        .font(.subheadline)
                        .foregroundStyle(TimelineTheme.textSecondary)
                case .openAI:
                    openAIConfiguration
                case .localModel:
                    Text("内置小模型入口已预留，当前版本暂不可用。后续可以直接接入本地 Provider。")
                        .font(.subheadline)
                        .foregroundStyle(TimelineTheme.textSecondary)
                }

                Divider()
                    .overlay(TimelineTheme.cardStroke)

                Toggle(
                    "同步日历到本地事件存储",
                    isOn: Binding(
                        get: { settingsStore.value.syncCalendarToStorage },
                        set: { viewModel.setSyncCalendarToStorage($0) }
                    )
                )
                Toggle(
                    "同步提醒事项到本地事件存储",
                    isOn: Binding(
                        get: { settingsStore.value.syncRemindersToStorage },
                        set: { viewModel.setSyncRemindersToStorage($0) }
                    )
                )

                Text("同步开关只决定是否把系统来源复制进 Pecker 自建存储；不会修改原始日历或提醒事项。")
                    .font(.caption)
                    .foregroundStyle(TimelineTheme.textTertiary)
                    .fixedSize(horizontal: false, vertical: true)

                imageRecognitionControls
            }
        }
    }

    private var imageRecognitionControls: some View {
        VStack(alignment: .leading, spacing: 10) {
            Divider()
                .overlay(TimelineTheme.cardStroke)

            HStack {
                Text("图片/相机识别")
                    .font(.subheadline.weight(.semibold))
                Spacer(minLength: 8)
                Text(viewModel.imageRecognitionStatusText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(TimelineTheme.textSecondary)
            }

            HStack {
                PhotosPicker(
                    selection: $selectedPhoto,
                    matching: .images
                ) {
                    Label("选择图片", systemImage: "photo")
                }
                .buttonStyle(.borderedProminent)

                Button {
                    isCameraPresented = true
                } label: {
                    Label("拍照识别", systemImage: "camera")
                }
                .buttonStyle(.bordered)
                .disabled(!UIImagePickerController.isSourceTypeAvailable(.camera))
            }

            if let imageRecognitionErrorText {
                Text(imageRecognitionErrorText)
                    .font(.caption)
                    .foregroundStyle(.red)
            }
        }
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task {
                await recognizePhoto(item)
                selectedPhoto = nil
            }
        }
        .sheet(isPresented: $isCameraPresented) {
            CameraCaptureView(
                onImage: { image in
                    isCameraPresented = false
                    Task { await recognizeCameraImage(image) }
                },
                onCancel: {
                    isCameraPresented = false
                }
            )
            .ignoresSafeArea()
        }
    }

    private var openAIConfiguration: some View {
        VStack(alignment: .leading, spacing: 12) {
            LabeledContent("Host") {
                TextField(
                    "https://api.openai.com",
                    text: Binding(
                        get: { settingsStore.value.openAIHost },
                        set: { viewModel.setOpenAIHost($0) }
                    )
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .keyboardType(.URL)
                .multilineTextAlignment(.trailing)
            }

            LabeledContent("Model") {
                TextField(
                    "gpt-5.4-mini",
                    text: Binding(
                        get: { settingsStore.value.openAIModel },
                        set: { viewModel.setOpenAIModel($0) }
                    )
                )
                .textInputAutocapitalization(.never)
                .autocorrectionDisabled()
                .multilineTextAlignment(.trailing)
            }

            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text("API Key")
                    Spacer(minLength: 8)
                    Text(viewModel.openAIAPIKeyStatusText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(TimelineTheme.textSecondary)
                }

                SecureField("sk-...", text: $apiKeyDraft)
                    .textInputAutocapitalization(.never)
                    .autocorrectionDisabled()
                    .textFieldStyle(.roundedBorder)

                HStack {
                    Button("保存 Key") {
                        saveOpenAIAPIKey()
                    }
                    .buttonStyle(.borderedProminent)
                    .disabled(
                        apiKeyDraft.trimmingCharacters(in: .whitespacesAndNewlines)
                            .isEmpty
                    )

                    Button("清除") {
                        clearOpenAIAPIKey()
                    }
                    .buttonStyle(.bordered)

                    Spacer(minLength: 8)
                }

                if let apiKeyErrorText {
                    Text(apiKeyErrorText)
                        .font(.caption)
                        .foregroundStyle(.red)
                }
            }

            Text("API Key 会保存到系统 Keychain；设置文件只记录是否已配置。")
                .font(.caption)
                .foregroundStyle(TimelineTheme.textTertiary)
        }
    }

    private var liveActivityCard: some View {
        TimelineCard(accent: .pinned) {
            VStack(alignment: .leading, spacing: 10) {
                Text("Live Activity")
                    .font(.headline.weight(.semibold))

                Toggle(
                    "锁定屏幕与灵动岛",
                    isOn: Binding(
                        get: { settingsStore.value.liveActivityEnabled },
                        set: { viewModel.setLiveActivityEnabled($0) }
                    )
                )

                HStack {
                    Text("状态")
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

    private func label(for mode: AIRecognitionMode) -> String {
        switch mode {
        case .off:
            return "关闭"
        case .openAI:
            return "OpenAI"
        case .localModel:
            return "本地"
        }
    }

    private func saveOpenAIAPIKey() {
        do {
            try viewModel.saveOpenAIAPIKey(apiKeyDraft)
            apiKeyDraft = ""
            apiKeyErrorText = nil
        } catch {
            apiKeyErrorText = "保存失败，请稍后重试。"
        }
    }

    private func clearOpenAIAPIKey() {
        do {
            try viewModel.clearOpenAIAPIKey()
            apiKeyDraft = ""
            apiKeyErrorText = nil
        } catch {
            apiKeyErrorText = "清除失败，请稍后重试。"
        }
    }

    private func recognizePhoto(_ item: PhotosPickerItem) async {
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                imageRecognitionErrorText = "无法读取图片。"
                return
            }
            try await viewModel.recognizeImportedImage(
                data,
                filename: item.itemIdentifier
            )
            imageRecognitionErrorText = nil
        } catch {
            imageRecognitionErrorText = "图片识别失败，请稍后重试。"
        }
    }

    private func recognizeCameraImage(_ image: UIImage) async {
        do {
            guard let data = image.jpegData(compressionQuality: 0.9) else {
                imageRecognitionErrorText = "无法读取相机图片。"
                return
            }
            try await viewModel.recognizeCameraImage(data)
            imageRecognitionErrorText = nil
        } catch {
            imageRecognitionErrorText = "相机识别失败，请稍后重试。"
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
