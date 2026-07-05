import SwiftUI
import PeckerCore
import PhotosUI
import UIKit

struct TodayView: View {
    @Environment(\.calendar) private var calendar
    @Environment(\.openURL) private var openURL
    @Bindable var model: TodayViewModel
    @Bindable var settingsStore: SettingsStore
    let imageRecognizer: any ImageRecognizing
    let onSettingsChanged: @MainActor @Sendable () -> Void
    @State private var path: [TodayRoute] = []
    @State private var isSettingsPresented = false
    @State private var selectedPhoto: PhotosPickerItem?
    @State private var isCameraPresented = false
    @State private var imageRecognitionPhase: TodayScreenContent.ImageRecognitionPhase = .idle
    @State private var pendingDelete: TimelineItem?
    @State private var mutationError: String?

    var body: some View {
        let localizer = AppLocalizer(language: settingsStore.value.language)
        NavigationStack(path: $path) {
            TimelineView(.periodic(from: .now, by: 60)) { context in
                TodayScreen(
                    content: content(now: context.date),
                    recognitionActions: TodayScreenContent.recognitionActions(
                        settings: settingsStore.value,
                        phase: imageRecognitionPhase,
                        localizer: localizer
                    ),
                    localizer: localizer,
                    selectedPhoto: $selectedPhoto,
                    isCameraPresented: $isCameraPresented,
                    refreshAction: { await model.refresh() },
                    onOpenSettings: {
                        isSettingsPresented = true
                    },
                    onOpenCard: { card in
                        if let item = model.state.snapshot?.item(
                            resolving: card.id
                        ) {
                            path.append(.detail(item: item))
                        }
                    },
                    onOpenConcurrentItems: {
                        path.append(.timeline(activeOnly: true))
                    },
                    onOpenSummary: {
                        path.append(.timeline(activeOnly: false))
                    },
                    canDeleteCard: { card in
                        guard let item = model.state.snapshot?.item(
                            resolving: card.id
                        ) else {
                            return false
                        }
                        return model.timelineManager.isEditable(item)
                    },
                    onDeleteCard: { card in
                        if let item = model.state.snapshot?.item(
                            resolving: card.id
                        ) {
                            pendingDelete = item
                        }
                    },
                    onRetry: {
                        Task { await model.refresh() }
                    },
                    onRecognizePhoto: { item in
                        await recognizePhoto(item)
                    },
                    onRecognizeCameraImage: { image in
                        await recognizeCameraImage(image)
                    },
                    onSaveRecognition: {
                        Task { await saveRecognitionDraft() }
                    },
                    onCancelRecognition: {
                        cancelRecognitionDraft()
                    }
                )
            }
            .navigationDestination(for: TodayRoute.self) { route in
                destination(for: route)
            }
            .sheet(isPresented: $isSettingsPresented) {
                SettingsView(
                    settingsStore: settingsStore,
                    viewModel: Self.makeSettingsViewModel(
                        settingsStore: settingsStore,
                        gateway: model.eventKitGateway,
                        authorization: model.latestAuthorization ?? .init(
                            calendar: .notDetermined,
                            reminders: .notDetermined
                        ),
                        liveActivityStatusText: {
                            model.liveActivityStatusText
                        },
                        onSettingsChanged: onSettingsChanged,
                        openURL: { url in
                            openURL(url)
                        }
                    )
                )
            }
            .alert(
                localizer.string("delete.confirmation.title"),
                isPresented: Binding(
                    get: { pendingDelete != nil },
                    set: { if !$0 { pendingDelete = nil } }
                ),
            ) {
                Button(localizer.string("common.delete"), role: .destructive) {
                    guard let item = pendingDelete else { return }
                    pendingDelete = nil
                    Task {
                        do {
                            try await model.timelineManager.delete(item)
                        } catch {
                            mutationError = localizer.string("delete.error")
                        }
                    }
                }
                Button(localizer.string("common.cancel"), role: .cancel) {
                    pendingDelete = nil
                }
            } message: {
                Text(localizer.string("delete.confirmation.message"))
            }
            .alert(
                localizer.string("operation.failed"),
                isPresented: Binding(
                    get: { mutationError != nil },
                    set: { if !$0 { mutationError = nil } }
                )
            ) {
                Button(localizer.string("common.ok")) { mutationError = nil }
            } message: {
                Text(mutationError ?? "")
            }
            .environment(\.locale, localizer.locale)
        }
    }

    private func content(now: Date) -> TodayScreenContent {
        let localizer = AppLocalizer(language: settingsStore.value.language)
        return TodayScreenContent.make(
            from: model.state,
            now: now,
            authorization: model.latestAuthorization,
            settings: settingsStore.value,
            localizer: localizer,
            locale: localizer.locale,
            calendar: calendar
        )
    }

    @ViewBuilder
    private func destination(for route: TodayRoute) -> some View {
        switch route {
        case let .timeline(activeOnly):
            FullTimelineView(
                model: model.timelineManager,
                now: .now,
                settings: settingsStore.value,
                localizer: AppLocalizer(language: settingsStore.value.language),
                activeOnly: activeOnly,
                onSelectItem: { item in
                    path.append(.detail(item: item))
                },
                onTogglePin: { item in
                    togglePin(for: item)
                },
                onOpenSettings: {
                    isSettingsPresented = true
                }
            )
        case let .detail(item):
            ItemDetailView(
                item: item,
                now: .now,
                settingsStore: settingsStore,
                localizer: AppLocalizer(language: settingsStore.value.language),
                timelineManager: model.timelineManager,
                onSettingsChanged: onSettingsChanged
            )
        }
    }

    private func togglePin(for item: TimelineItem) {
        settingsStore.update {
            $0 = ItemDetailAction.updatedSettings(
                byTogglingPinFor: item,
                settings: $0
            )
        }
        onSettingsChanged()
    }

    private func recognizePhoto(_ item: PhotosPickerItem) async {
        imageRecognitionPhase = .recognizing
        do {
            guard let data = try await item.loadTransferable(type: Data.self) else {
                imageRecognitionPhase = .failure(.init(
                    reason: AppLocalizer(language: settingsStore.value.language)
                        .string("recognition.error.photoUnreadable"),
                    technicalDetails: nil
                ))
                return
            }

            let draft = try await imageRecognizer.recognizeImage(
                data: data,
                source: .importedImage,
                filename: item.itemIdentifier,
                settings: settingsStore.value,
                now: .now
            )
            imageRecognitionPhase = .awaitingConfirmation(draft)
        } catch {
            imageRecognitionPhase = .failure(issuePresentation(for: error))
        }
    }

    private func recognizeCameraImage(_ image: UIImage) async {
        imageRecognitionPhase = .recognizing
        do {
            guard let data = image.jpegData(compressionQuality: 0.88) else {
                imageRecognitionPhase = .failure(.init(
                    reason: AppLocalizer(language: settingsStore.value.language)
                        .string("recognition.error.cameraUnreadable"),
                    technicalDetails: nil
                ))
                return
            }

            let draft = try await imageRecognizer.recognizeImage(
                data: data,
                source: .cameraImage,
                filename: "camera.jpg",
                settings: settingsStore.value,
                now: .now
            )
            imageRecognitionPhase = .awaitingConfirmation(draft)
        } catch {
            imageRecognitionPhase = .failure(issuePresentation(for: error))
        }
    }

    private func saveRecognitionDraft() async {
        let draft: ImageRecognitionDraft
        switch imageRecognitionPhase {
        case let .awaitingConfirmation(value),
             let .saveFailure(value, _):
            draft = value
        case .idle, .recognizing, .saving, .success, .failure:
            return
        }

        imageRecognitionPhase = .saving(draft)
        do {
            let savedRecord = try await imageRecognizer.saveRecognizedImage(draft)
            guard await model.timelineManager.revealSavedRecord(savedRecord) else {
                imageRecognitionPhase = .saveFailure(
                    draft,
                    AppLocalizer(language: settingsStore.value.language)
                        .string("recognition.save.failure")
                )
                return
            }
            imageRecognitionPhase = .success(
                AppLocalizer(language: settingsStore.value.language)
                    .string("recognition.save.success")
            )
            onSettingsChanged()
            await model.refresh()
            path.append(.timeline(activeOnly: false))
        } catch {
            imageRecognitionPhase = .saveFailure(
                draft,
                AppLocalizer(language: settingsStore.value.language)
                    .string("recognition.save.failure")
            )
        }
    }

    private func cancelRecognitionDraft() {
        switch imageRecognitionPhase {
        case .awaitingConfirmation, .saveFailure:
            imageRecognitionPhase = .idle
        case .idle, .recognizing, .saving, .success, .failure:
            break
        }
    }

    private func issuePresentation(
        for error: Error
    ) -> RecognitionIssuePresentation {
        if let failure = error as? RecognitionPipelineFailure {
            return .init(
                reason: failure.reason,
                technicalDetails: failure.technicalDetails
            )
        }
        guard let recognitionError = error as? RecognitionError else {
            return .init(
                reason: AppLocalizer(language: settingsStore.value.language)
                    .string("recognition.error.generic"),
                technicalDetails: error.localizedDescription
            )
        }

        let localizer = AppLocalizer(language: settingsStore.value.language)
        let reason = switch recognitionError {
        case .invalidConfiguration:
            localizer.string("recognition.error.invalidConfiguration")
        case .requestFailed:
            localizer.string("recognition.error.requestFailed")
        case .imageInputUnsupported:
            localizer.string("recognition.error.imageUnsupported")
        case .invalidResponse:
            localizer.string("recognition.error.invalidResponse")
        case .networkExecutionNotImplemented:
            localizer.string("recognition.error.networkNotImplemented")
        case .unsupportedInput:
            localizer.string("recognition.error.unsupportedInput")
        }
        return .init(
            reason: reason,
            technicalDetails: localizer.string(
                "recognition.error.type",
                "\(recognitionError)"
            )
        )
    }

    @MainActor
    static func makeSettingsViewModel(
        settingsStore: SettingsStore,
        gateway: (any EventKitGatewayProtocol)? = nil,
        authorization: SourceAuthorization,
        liveActivityStatusText: @escaping @MainActor () -> String,
        onSettingsChanged: @escaping @MainActor () -> Void,
        openURL: @escaping (URL) -> Void
    ) -> SettingsViewModel {
        SettingsViewModel(
            settingsStore: settingsStore,
            gateway: gateway,
            authorization: authorization,
            liveActivityStatusText: liveActivityStatusText,
            onSettingsChanged: onSettingsChanged,
            openURL: openURL
        )
    }
}

private enum TodayRoute: Hashable {
    case timeline(activeOnly: Bool)
    case detail(item: TimelineItem)
}

struct TodayScreen: View {
    let content: TodayScreenContent
    let recognitionActions: TodayScreenContent.RecognitionActions?
    let localizer: AppLocalizer
    @Binding var selectedPhoto: PhotosPickerItem?
    @Binding var isCameraPresented: Bool
    let refreshAction: () async -> Void
    let onOpenSettings: () -> Void
    let onOpenCard: (TodayScreenContent.Card) -> Void
    let onOpenConcurrentItems: () -> Void
    let onOpenSummary: () -> Void
    let canDeleteCard: (TodayScreenContent.Card) -> Bool
    let onDeleteCard: (TodayScreenContent.Card) -> Void
    let onRetry: () -> Void
    let onRecognizePhoto: (PhotosPickerItem) async -> Void
    let onRecognizeCameraImage: (UIImage) async -> Void
    let onSaveRecognition: () -> Void
    let onCancelRecognition: () -> Void

    init(
        content: TodayScreenContent,
        recognitionActions: TodayScreenContent.RecognitionActions? = nil,
        localizer: AppLocalizer = AppLocalizer(language: .system),
        selectedPhoto: Binding<PhotosPickerItem?> = .constant(nil),
        isCameraPresented: Binding<Bool> = .constant(false),
        refreshAction: @escaping () async -> Void,
        onOpenSettings: @escaping () -> Void,
        onOpenCard: @escaping (TodayScreenContent.Card) -> Void,
        onOpenConcurrentItems: @escaping () -> Void,
        onOpenSummary: @escaping () -> Void,
        canDeleteCard: @escaping (TodayScreenContent.Card) -> Bool = { _ in false },
        onDeleteCard: @escaping (TodayScreenContent.Card) -> Void = { _ in },
        onRetry: @escaping () -> Void,
        onRecognizePhoto: @escaping (PhotosPickerItem) async -> Void = { _ in },
        onRecognizeCameraImage: @escaping (UIImage) async -> Void = { _ in },
        onSaveRecognition: @escaping () -> Void = {},
        onCancelRecognition: @escaping () -> Void = {}
    ) {
        self.content = content
        self.recognitionActions = recognitionActions
        self.localizer = localizer
        _selectedPhoto = selectedPhoto
        _isCameraPresented = isCameraPresented
        self.refreshAction = refreshAction
        self.onOpenSettings = onOpenSettings
        self.onOpenCard = onOpenCard
        self.onOpenConcurrentItems = onOpenConcurrentItems
        self.onOpenSummary = onOpenSummary
        self.canDeleteCard = canDeleteCard
        self.onDeleteCard = onDeleteCard
        self.onRetry = onRetry
        self.onRecognizePhoto = onRecognizePhoto
        self.onRecognizeCameraImage = onRecognizeCameraImage
        self.onSaveRecognition = onSaveRecognition
        self.onCancelRecognition = onCancelRecognition
    }

    var body: some View {
        ZStack {
            TimelineTheme.backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        header
                        if let recognitionActions {
                            recognitionActionsView(recognitionActions)
                        }
                        bodyContent
                    }
                    .frame(maxWidth: 640, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.top, 14)
                    .padding(.bottom, 14)
                }
            }
        }
        .foregroundStyle(TimelineTheme.textPrimary)
        .refreshable {
            await refreshAction()
        }
        .onChange(of: selectedPhoto) { _, item in
            guard let item else { return }
            Task {
                await onRecognizePhoto(item)
                selectedPhoto = nil
            }
        }
        .sheet(isPresented: $isCameraPresented) {
            CameraCaptureView(
                onImage: { image in
                    isCameraPresented = false
                    Task { await onRecognizeCameraImage(image) }
                },
                onCancel: {
                    isCameraPresented = false
                }
            )
            .ignoresSafeArea()
        }
    }

    private var header: some View {
        HStack(alignment: .top) {
            VStack(alignment: .leading, spacing: 8) {
                Text(content.header.dateText)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(TimelineTheme.textSecondary)

                Text(content.header.todayText)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .kerning(-0.3)
            }
            .accessibilityElement(children: .ignore)
            .accessibilityLabel(content.header.accessibilityLabel)

            Spacer(minLength: 12)

            Button(action: onOpenSettings) {
                    Image(systemName: "gearshape.fill")
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(TimelineTheme.textPrimary)
                    .frame(width: 40, height: 40)
                    .background(
                        Circle()
                            .fill(TimelineTheme.controlFill)
                    )
                    .overlay(
                        Circle()
                            .stroke(TimelineTheme.cardStroke, lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(content.header.settingsButtonLabel)
        }
        .padding(.top, 4)
    }

    private func recognitionActionsView(
        _ actions: TodayScreenContent.RecognitionActions
    ) -> some View {
        TimelineCard(accent: .now) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 10) {
                    VStack(alignment: .leading, spacing: 3) {
                        Text(localizer.string("recognition.title"))
                            .font(.headline.weight(.semibold))
                        Text(actions.statusText)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(TimelineTheme.textSecondary)
                    }

                    Spacer(minLength: 8)

                    if actions.showsTypingIndicator {
                        RecognitionTypingIndicator()
                    } else if actions.isLoading {
                        ProgressView()
                            .tint(TimelineTheme.now)
                            .accessibilityLabel(localizer.string("recognition.saving.accessibility"))
                    }
                }

                HStack(spacing: 10) {
                    PhotosPicker(
                        selection: $selectedPhoto,
                        matching: .images
                    ) {
                        RecognitionActionLabel(
                            title: localizer.string("recognition.photo.title"),
                            subtitle: localizer.string("recognition.photo.subtitle"),
                            symbol: "photo.on.rectangle.angled",
                            accent: TimelineTheme.now
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(actions.buttonsDisabled)
                    .opacity(actions.buttonsDisabled ? 0.58 : 1)

                    Button {
                        isCameraPresented = true
                    } label: {
                        RecognitionActionLabel(
                            title: localizer.string("recognition.camera.title"),
                            subtitle: localizer.string("recognition.camera.subtitle"),
                            symbol: "camera.viewfinder",
                            accent: TimelineTheme.pinned
                        )
                    }
                    .buttonStyle(.plain)
                    .disabled(
                        actions.buttonsDisabled
                            || !UIImagePickerController.isSourceTypeAvailable(.camera)
                    )
                    .opacity(
                        actions.buttonsDisabled
                            || !UIImagePickerController.isSourceTypeAvailable(.camera)
                            ? 0.48
                            : 1
                    )
                }

                if let errorText = actions.errorText {
                    Text(errorText)
                        .font(.caption)
                        .foregroundStyle(TimelineTheme.now)
                        .fixedSize(horizontal: false, vertical: true)
                }

                if let details = actions.errorTechnicalDetails,
                   !details.isEmpty {
                    DisclosureGroup(localizer.string("recognition.technicalDetails")) {
                        Text(details)
                            .font(.caption.monospaced())
                            .foregroundStyle(TimelineTheme.textSecondary)
                            .textSelection(.enabled)
                            .fixedSize(horizontal: false, vertical: true)
                            .padding(.top, 4)
                    }
                    .font(.caption.weight(.medium))
                    .accessibilityLabel(localizer.string("recognition.technicalDetails.accessibility"))
                }

                if let preview = actions.preview {
                    recognitionPreview(preview)
                }
            }
        }
    }

    private func recognitionPreview(
        _ preview: TodayScreenContent.RecognitionPreview
    ) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Divider()
                .overlay(TimelineTheme.cardStroke)

            VStack(alignment: .leading, spacing: 5) {
                Text(localizer.string("recognition.preview.title"))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(TimelineTheme.now)

                Text(preview.titleText)
                    .font(.title3.weight(.semibold))
                    .fixedSize(horizontal: false, vertical: true)

                if let subtitleText = preview.subtitleText {
                    Text(subtitleText)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(TimelineTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }

            if !preview.fields.isEmpty {
                VStack(spacing: 8) {
                    ForEach(
                        Array(preview.fields.enumerated()),
                        id: \.offset
                    ) { _, field in
                        HStack(alignment: .firstTextBaseline, spacing: 12) {
                            Text(field.label)
                                .font(.caption.weight(.medium))
                                .foregroundStyle(TimelineTheme.textTertiary)
                                .frame(width: 64, alignment: .leading)

                            Text(field.value)
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(TimelineTheme.textPrimary)

                            Spacer(minLength: 0)
                        }
                    }
                }
            }

            if let errorText = preview.errorText {
                Text(errorText)
                    .font(.caption)
                    .foregroundStyle(TimelineTheme.now)
                    .fixedSize(horizontal: false, vertical: true)
            }

            HStack(spacing: 10) {
                Button(preview.saveButtonText, action: onSaveRecognition)
                    .buttonStyle(
                        RecognitionConfirmationButtonStyle(
                            accent: TimelineTheme.now,
                            filled: true
                        )
                    )

                Button(preview.cancelButtonText, action: onCancelRecognition)
                    .buttonStyle(
                        RecognitionConfirmationButtonStyle(
                            accent: TimelineTheme.textPrimary,
                            filled: false
                        )
                    )

                Spacer(minLength: 0)
            }
            .disabled(preview.buttonsDisabled)
            .opacity(preview.buttonsDisabled ? 0.58 : 1)
        }
    }

    @ViewBuilder
    private var bodyContent: some View {
        switch content.mode {
        case .loading:
            loadingState
        case let .empty(sourceNotice):
            emptyState(sourceNotice)
        case .permission:
            permissionState
        case .stale:
            staleTimeline
        case .failure:
            failureState
        case .content:
            liveTimeline
        }
    }

    private var loadingState: some View {
        centeredState(
            icon: "clock.arrow.circlepath",
            title: TodayStateCopy.loadingTitle(localizer),
            message: localizer.string("today.loading.message")
        ) {
            ProgressView()
                .tint(TimelineTheme.now)
        }
    }

    private func emptyState(_ sourceNotice: TodayScreenContent.SourceNotice?) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            if let sourceNotice {
                sourceNoticeBanner(sourceNotice)
            }

            centeredState(
                icon: "calendar.badge.clock",
                title: TodayStateCopy.emptyTitle(localizer),
                message: localizer.string("today.empty.message")
            ) {
                Button(TodayStateCopy.staleRetry(localizer)) {
                    onRetry()
                }
                .buttonStyle(.plain)
                .font(.headline.weight(.semibold))
                .foregroundStyle(TimelineTheme.now)
            }

            if let summary = content.summary {
                summaryRow(summary)
            }
        }
    }

    private var permissionState: some View {
        let permission = content.permission
        return TimelineCard(accent: .neutral) {
            VStack(alignment: .leading, spacing: 16) {
                Label {
                    Text(permission?.titleText ?? TodayStateCopy.permissionTitle(localizer))
                        .font(.headline.weight(.semibold))
                } icon: {
                    Image(systemName: "hand.raised.fill")
                        .foregroundStyle(TimelineTheme.neutral)
                }
                .labelStyle(.titleAndIcon)

                Text(permission?.bodyText ?? localizer.string("today.permission.body.noMissing"))
                    .font(.body)
                    .foregroundStyle(TimelineTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button(permission?.buttonText ?? TodayStateCopy.permissionButton(localizer)) {
                    onOpenSettings()
                }
                .buttonStyle(.plain)
                .font(.headline.weight(.semibold))
                .foregroundStyle(TimelineTheme.next)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    private var failureState: some View {
        let failure = content.failure
        return TimelineCard(accent: .neutral) {
            VStack(alignment: .leading, spacing: 16) {
                Label {
                    Text(failure?.titleText ?? TodayStateCopy.failureTitle(localizer))
                        .font(.headline.weight(.semibold))
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.orange)
                }
                .labelStyle(.titleAndIcon)

                Text(failure?.bodyText ?? localizer.string("today.failure.message"))
                    .font(.body)
                    .foregroundStyle(TimelineTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button(failure?.retryText ?? TodayStateCopy.failureRetry(localizer)) {
                    onRetry()
                }
                .buttonStyle(.plain)
                .font(.headline.weight(.semibold))
                .foregroundStyle(TimelineTheme.now)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
        .accessibilityElement(children: .combine)
    }

    private var staleTimeline: some View {
        VStack(alignment: .leading, spacing: 10) {
            staleBanner
            liveTimeline
        }
    }

    private var staleBanner: some View {
        let stale = content.stale
        return TimelineCard(accent: .neutral) {
            HStack(alignment: .center, spacing: 12) {
                Image(systemName: "exclamationmark.triangle.fill")
                    .foregroundStyle(Color.orange)
                    .accessibilityHidden(true)

                Text(stale?.bannerText ?? TodayStateCopy.staleBanner(localizer))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(TimelineTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)

                Button(stale?.retryText ?? TodayStateCopy.staleRetry(localizer)) {
                    onRetry()
                }
                .buttonStyle(.plain)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(TimelineTheme.next)
            }
        }
    }

    private func sourceNoticeBanner(
        _ notice: TodayScreenContent.SourceNotice
    ) -> some View {
        TimelineCard(accent: .neutral) {
            VStack(alignment: .leading, spacing: 12) {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: "exclamationmark.shield.fill")
                        .foregroundStyle(Color.orange)
                        .accessibilityHidden(true)

                    Text(notice.titleText)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(TimelineTheme.textPrimary)

                    Spacer(minLength: 8)
                }

                Text(notice.bodyText)
                    .font(.subheadline)
                    .foregroundStyle(TimelineTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button(notice.buttonText) {
                    onOpenSettings()
                }
                .buttonStyle(.plain)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(TimelineTheme.next)
                .accessibilityLabel(notice.accessibilityLabel)
            }
        }
    }

    private var liveTimeline: some View {
        VStack(alignment: .leading, spacing: 10) {
            if let sourceNotice = content.sourceNotice {
                sourceNoticeBanner(sourceNotice)
            }

            if let nowCard = content.nowCard {
                timelineRow(
                    card: nowCard,
                    topLine: false,
                    bottomLine: true
                )
            }

            if let nextCard = content.nextCard {
                timelineRow(
                    card: nextCard,
                    topLine: content.nowCard != nil,
                    bottomLine: content.pinnedCard != nil
                )
            }

            if let pinnedCard = content.pinnedCard {
                timelineRow(
                    card: pinnedCard,
                    topLine: content.nowCard != nil || content.nextCard != nil,
                    bottomLine: false
                )
            }

            if let summary = content.summary {
                summaryRow(summary)
            }

            if let footer = content.footer {
                footerRow(footer)
            }
        }
    }

    private func timelineRow(
        card: TodayScreenContent.Card,
        topLine: Bool,
        bottomLine: Bool
    ) -> some View {
        SwipeDeleteAction(
            isEnabled: canDeleteCard(card),
            onTap: { onOpenCard(card) },
            onDelete: { onDeleteCard(card) }
        ) {
            HStack(alignment: .top, spacing: 12) {
                TimelineRailMarker(
                    accent: card.accent,
                    topLine: topLine,
                    bottomLine: bottomLine
                )

                TimelineCard(accent: card.accent) {
                    cardBody(card)
                }
            }
        }
        .accessibilityLabel(card.accessibilityLabel)
    }

    @ViewBuilder
    private func cardBody(_ card: TodayScreenContent.Card) -> some View {
        switch card.kind {
        case .now:
            nowCard(card)
        case .next:
            nextCard(card)
        case .pinned:
            pinnedCard(card)
        }
    }

    private func nowCard(_ card: TodayScreenContent.Card) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            cardHeader(card)

            VStack(alignment: .leading, spacing: 6) {
                Text(card.titleText)
                    .font(.title3.weight(.semibold))
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)

                Text(card.timeText)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(TimelineTheme.textSecondary)
            }

            if let secondary = card.secondaryText {
                Text(secondary)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(TimelineTheme.color(for: card.accent))
            }

            if let progress = card.progress {
                HStack(alignment: .center, spacing: 12) {
                    TimelineProgressBar(
                        progress: progress,
                        accent: card.accent
                    )

                    if let progressText = card.progressText {
                        Text(progressText)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(TimelineTheme.textPrimary)
                    }
                }
            }

            if let tertiary = card.tertiaryText {
                Text(tertiary)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(TimelineTheme.textSecondary)
            }
        }
    }

    private func nextCard(_ card: TodayScreenContent.Card) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            cardHeader(card)

            VStack(alignment: .leading, spacing: 6) {
                Text(card.titleText)
                    .font(.title3.weight(.semibold))
                    .lineLimit(nil)
                    .fixedSize(horizontal: false, vertical: true)

                Text(card.timeText)
                    .font(.subheadline.weight(.medium))
                    .foregroundStyle(TimelineTheme.textSecondary)

                if let secondary = card.secondaryText {
                    Text(secondary)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(TimelineTheme.color(for: card.accent))
                }
            }
        }
    }

    private func pinnedCard(_ card: TodayScreenContent.Card) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack(alignment: .top) {
                Text(card.statusText)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(TimelineTheme.color(for: card.accent))

                Spacer(minLength: 8)

                if let badgeText = card.badgeText {
                    Text(badgeText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(TimelineTheme.textPrimary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                        .background(
                            Capsule().fill(TimelineTheme.color(for: card.accent).opacity(0.12))
                        )
                        .overlay(
                            Capsule().stroke(TimelineTheme.color(for: card.accent).opacity(0.18), lineWidth: 1)
                        )
                }
            }

            HStack(alignment: .center, spacing: 12) {
                iconBubble(card)

                VStack(alignment: .leading, spacing: 6) {
                    Text(card.titleText)
                        .font(.title3.weight(.semibold))
                        .lineLimit(nil)
                        .fixedSize(horizontal: false, vertical: true)

                    Text(card.timeText)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(TimelineTheme.textSecondary)

                    if let secondary = card.secondaryText {
                        Text(secondary)
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(TimelineTheme.textSecondary)
                    }

                    if let tertiary = card.tertiaryText {
                        Text(tertiary)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(TimelineTheme.color(for: card.accent))
                    }
                }
            }
        }
    }

    private func summaryRow(_ summary: TodayScreenContent.Summary) -> some View {
        Button(action: onOpenSummary) {
            TimelineCard(accent: .neutral) {
                HStack(alignment: .center, spacing: 10) {
                    Image(systemName: "calendar")
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(TimelineTheme.textPrimary)
                        .frame(width: 24, height: 24)
                        .background(Circle().fill(TimelineTheme.controlFill))
                        .overlay(Circle().stroke(TimelineTheme.cardStroke, lineWidth: 1))

                    Text(summary.titleText)
                        .font(.footnote.weight(.medium))
                        .foregroundStyle(TimelineTheme.textPrimary)
                        .fixedSize(horizontal: false, vertical: true)

                    Spacer(minLength: 8)

                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(TimelineTheme.textTertiary)
                }
            }
        }
        .buttonStyle(.plain)
        .accessibilityLabel(summary.accessibilityLabel)
    }

    private func footerRow(_ footer: TodayScreenContent.Footer) -> some View {
        Text(footer.generatedAtText)
            .font(.caption.weight(.medium))
            .foregroundStyle(TimelineTheme.textTertiary)
            .frame(maxWidth: .infinity)
            .padding(.top, 2)
            .padding(.bottom, 2)
            .accessibilityLabel(footer.generatedAtText)
    }

    private func cardHeader(_ card: TodayScreenContent.Card) -> some View {
        HStack(alignment: .top) {
            Text(card.statusText)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(TimelineTheme.color(for: card.accent))

            Spacer(minLength: 8)

            if let badgeText = card.badgeText {
                Text(badgeText)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(TimelineTheme.textPrimary)
                        .padding(.horizontal, 9)
                        .padding(.vertical, 4)
                    .background(
                        Capsule().fill(TimelineTheme.color(for: card.accent).opacity(0.12))
                    )
                    .overlay(
                        Capsule().stroke(TimelineTheme.color(for: card.accent).opacity(0.18), lineWidth: 1)
                    )
            } else {
                iconBubble(card)
            }
        }
    }

    private func iconBubble(_ card: TodayScreenContent.Card) -> some View {
        Image(systemName: card.symbolName)
            .font(.system(size: 16, weight: .semibold))
            .foregroundStyle(TimelineTheme.color(for: card.accent))
            .frame(width: 38, height: 38)
            .background(Circle().fill(TimelineTheme.iconBackground(for: card.accent)))
            .overlay(Circle().stroke(TimelineTheme.color(for: card.accent).opacity(0.2), lineWidth: 1))
            .accessibilityHidden(true)
    }

    private func centeredState<Accessory: View>(
        icon: String,
        title: String,
        message: String,
        @ViewBuilder accessory: () -> Accessory
    ) -> some View {
        VStack(spacing: 14) {
            TimelineCard(accent: .neutral) {
                VStack(alignment: .center, spacing: 14) {
                    Image(systemName: icon)
                        .font(.system(size: 28, weight: .semibold))
                        .foregroundStyle(TimelineTheme.neutral)
                        .accessibilityHidden(true)

                    VStack(alignment: .center, spacing: 10) {
                        Text(title)
                            .font(.headline.weight(.semibold))
                            .multilineTextAlignment(.center)

                        Text(message)
                            .font(.body)
                            .foregroundStyle(TimelineTheme.textSecondary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }

                    accessory()
                }
                .frame(maxWidth: .infinity)
            }
        }
    }
}

private struct TimelineRailMarker: View {
    let accent: TimelineAccent
    let topLine: Bool
    let bottomLine: Bool

    var body: some View {
        VStack(spacing: 0) {
            if topLine {
                Rectangle()
                    .fill(TimelineTheme.lineColor(for: accent).opacity(0.5))
                    .frame(width: 2)
                    .frame(height: 12)
            } else {
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 2)
                    .frame(height: 12)
            }

            Circle()
                .fill(TimelineTheme.lineColor(for: accent))
                .frame(width: 13, height: 13)
                .overlay(Circle().stroke(Color.white.opacity(0.7), lineWidth: 2))
                .shadow(color: TimelineTheme.lineColor(for: accent).opacity(0.18), radius: 10, x: 0, y: 4)

            if bottomLine {
                Rectangle()
                    .fill(TimelineTheme.lineColor(for: accent).opacity(0.55))
                    .frame(width: 2)
                    .frame(height: 12)
            } else {
                Rectangle()
                    .fill(Color.clear)
                    .frame(width: 2)
                    .frame(height: 12)
            }
        }
        .frame(width: 20)
        .padding(.top, 8)
        .accessibilityHidden(true)
    }
}

private struct RecognitionActionLabel: View {
    let title: String
    let subtitle: String
    let symbol: String
    let accent: Color

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: symbol)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(accent)
                .frame(width: 34, height: 34)
                .background(Circle().fill(accent.opacity(0.11)))
                .overlay(Circle().stroke(accent.opacity(0.18), lineWidth: 1))

            VStack(alignment: .leading, spacing: 2) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(TimelineTheme.textPrimary)
                Text(subtitle)
                    .font(.caption.weight(.medium))
                    .foregroundStyle(TimelineTheme.textTertiary)
            }

            Spacer(minLength: 0)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 11)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .fill(TimelineTheme.controlFill)
        )
        .overlay(
            RoundedRectangle(cornerRadius: 18, style: .continuous)
                .stroke(TimelineTheme.cardStroke, lineWidth: 1)
        )
    }
}

private struct RecognitionTypingIndicator: View {
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Group {
            if reduceMotion {
                Text("…")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(TimelineTheme.now)
            } else {
                TimelineView(.animation(minimumInterval: 0.18)) { context in
                    let activeIndex = Int(
                        context.date.timeIntervalSinceReferenceDate * 3
                    ) % 3
                    HStack(spacing: 4) {
                        ForEach(0..<3, id: \.self) { index in
                            Circle()
                                .fill(TimelineTheme.now)
                                .frame(width: 6, height: 6)
                                .opacity(index == activeIndex ? 1 : 0.28)
                                .offset(y: index == activeIndex ? -2 : 0)
                        }
                    }
                }
            }
        }
        .frame(width: 34, height: 20)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("Recognizing image")
    }
}

private struct RecognitionConfirmationButtonStyle: ButtonStyle {
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
                    .stroke(
                        filled ? Color.clear : TimelineTheme.cardStroke,
                        lineWidth: 1
                    )
            )
            .opacity(configuration.isPressed ? 0.72 : 1)
    }
}

private struct TimelineProgressBar: View {
    let progress: Double
    let accent: TimelineAccent

    private let segments = 20

    var body: some View {
        HStack(spacing: 2) {
            ForEach(0..<segments, id: \.self) { index in
                Capsule()
                    .fill(segmentFill(for: index))
                    .frame(width: 7, height: 7)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .accessibilityLabel("Progress \(Int((progress * 100).rounded()))%")
    }

    private func segmentFill(for index: Int) -> Color {
        let threshold = Double(index + 1) / Double(segments)
        return threshold <= progress
            ? TimelineTheme.color(for: accent)
            : TimelineTheme.textPrimary.opacity(0.1)
    }
}

private struct TodayRoutePlaceholder: View {
    let route: TodayRoute

    var body: some View {
        ZStack {
            TimelineTheme.backgroundGradient
                .ignoresSafeArea()

            TimelineCard(accent: .neutral) {
                VStack(alignment: .leading, spacing: 12) {
                    Text(title)
                        .font(.title2.weight(.semibold))
                    Text(message)
                        .font(.body)
                        .foregroundStyle(TimelineTheme.textSecondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .padding()
        }
        .foregroundStyle(TimelineTheme.textPrimary)
        .navigationTitle(title)
        .navigationBarTitleDisplayMode(.inline)
    }

    private var title: String {
        switch route {
        case .timeline:
            "Full Timeline"
        case .detail:
            "Event Details"
        }
    }

    private var message: String {
        switch route {
        case .timeline:
            "No snapshot is available for this page."
        case .detail:
            "No item is available for details."
        }
    }
}
