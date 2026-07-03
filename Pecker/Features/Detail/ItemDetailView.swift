import SwiftUI
import PeckerCore

enum ItemDetailAction {
    static func primaryButtonTitle(
        for item: TimelineItem,
        settings: TimelineSettings,
        localizer: AppLocalizer = AppLocalizer(language: .simplifiedChinese)
    ) -> String {
        settings.manualPinnedSourceIdentifier == item.sourceIdentifier
            ? localizer.string("pin.action.unpin")
            : localizer.string("pin.action.pin")
    }

    static func updatedSettings(
        byTogglingPinFor item: TimelineItem,
        settings: TimelineSettings
    ) -> TimelineSettings {
        var updated = settings
        if updated.manualPinnedSourceIdentifier == item.sourceIdentifier {
            updated.manualPinnedSourceIdentifier = nil
        } else {
            updated.manualPinnedSourceIdentifier = item.sourceIdentifier
        }
        return updated
    }

    static func visibleCustomFields(
        _ fields: [EventCustomField]
    ) -> [EventCustomField] {
        fields.filter {
            !$0.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
                && !$0.value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }
    }
}

struct ItemDetailView: View {
    static let navigationTitleKey = "detail.title"

    @Environment(\.dismiss) private var dismiss
    @State private var displayedItem: TimelineItem
    @State private var editingRecord: TimelineRecordEditor?
    @State private var pendingDelete = false
    @State private var mutationError: String?
    @State private var isDeleting = false

    let now: Date
    @Bindable var settingsStore: SettingsStore
    let localizer: AppLocalizer
    let timelineManager: TimelineManagerModel?
    let onSettingsChanged: () -> Void

    init(
        item: TimelineItem,
        now: Date,
        settingsStore: SettingsStore,
        localizer: AppLocalizer = AppLocalizer(language: .system),
        timelineManager: TimelineManagerModel? = nil,
        onSettingsChanged: @escaping () -> Void
    ) {
        _displayedItem = State(initialValue: item)
        self.now = now
        self.settingsStore = settingsStore
        self.localizer = localizer
        self.timelineManager = timelineManager
        self.onSettingsChanged = onSettingsChanged
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header

                if case let .trainTicket(ticket) = displayedItem.template {
                    TrainTicketTemplateView(
                        ticket: ticket,
                        fallbackDepartureTime: displayedItem.startDate,
                        fallbackArrivalTime: displayedItem.endDate,
                        localizer: localizer
                    )
                }

                TimelineCard(accent: .neutral) {
                    VStack(alignment: .leading, spacing: 12) {
                        detailRow(title: localizer.string("detail.source"), value: sourceText)
                        detailRow(title: localizer.string("detail.kind"), value: kindText)
                        detailRow(title: localizer.string("common.time"), value: timingText(now: now))
                        detailRow(title: localizer.string("detail.location"), value: displayedItem.location.nilIfEmpty ?? "—")
                        detailRow(title: localizer.string("detail.notes"), value: displayedItem.notes.nilIfEmpty ?? "—")
                        ForEach(
                            ItemDetailAction.visibleCustomFields(
                                displayedItem.customFields
                            )
                        ) { field in
                            detailRow(title: field.name, value: field.value)
                        }
                    }
                }
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.top, 14)
            .padding(.bottom, 82)
        }
        .background(TimelineTheme.backgroundGradient.ignoresSafeArea())
        .foregroundStyle(TimelineTheme.textPrimary)
        .navigationTitle(localizer.string(Self.navigationTitleKey))
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            if isEditable {
                ToolbarItem(placement: .topBarTrailing) {
                    detailActionsMenu
                }
            }
        }
        .safeAreaInset(edge: .bottom) {
            pinActionInset
        }
        .sheet(item: $editingRecord) { editor in
            TimelineRecordEditorView(
                editor: editor,
                localizer: localizer
            ) { editor in
                try await save(editor)
            }
            .presentationDetents([.large])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(30)
        }
        .alert(
            localizer.string("delete.confirmation.title"),
            isPresented: $pendingDelete
        ) {
            Button(localizer.string("common.delete"), role: .destructive) {
                Task { await deleteDisplayedItem() }
            }
            Button(localizer.string("common.cancel"), role: .cancel) {
                pendingDelete = false
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
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(displayedItem.title)
                .font(.largeTitle.weight(.bold))
                .fixedSize(horizontal: false, vertical: true)

            Text(summaryText)
                .font(.subheadline)
                .foregroundStyle(TimelineTheme.textSecondary)
        }
    }

    private var detailActionsMenu: some View {
        Menu {
            Button(action: openEditor) {
                Label(localizer.string("common.edit"), systemImage: "pencil")
            }

            Button(role: .destructive) {
                pendingDelete = true
            } label: {
                Label(localizer.string("common.delete"), systemImage: "trash")
            }
            .disabled(isDeleting)
        } label: {
            Image(systemName: "ellipsis.circle")
                .font(.system(size: 18, weight: .semibold))
                .foregroundStyle(TimelineTheme.textPrimary)
        }
        .accessibilityLabel(localizer.string("common.moreActions"))
    }

    private var pinActionInset: some View {
        HStack {
            Spacer(minLength: 0)
            pinButton
            Spacer(minLength: 0)
        }
        .padding(.horizontal, 16)
        .padding(.top, 8)
        .padding(.bottom, 10)
        .background {
            LinearGradient(
                colors: [
                    TimelineTheme.cardFallbackFill.opacity(0),
                    TimelineTheme.cardFallbackFill.opacity(0.74)
                ],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        }
    }

    private var pinButton: some View {
        Button(action: togglePin) {
            Label {
                Text(
                    ItemDetailAction.primaryButtonTitle(
                        for: displayedItem,
                        settings: settingsStore.value,
                        localizer: localizer
                    )
                )
            } icon: {
                Image(systemName: isPinned ? "pin.fill" : "pin")
            }
            .font(.subheadline.weight(.semibold))
            .lineLimit(1)
            .minimumScaleFactor(0.86)
            .padding(.horizontal, 18)
            .frame(height: 46)
            .background {
                Capsule()
                    .fill(.regularMaterial)
                    .shadow(
                        color: TimelineTheme.cardShadow.opacity(0.72),
                        radius: 18,
                        x: 0,
                        y: 10
                    )
            }
            .overlay {
                Capsule()
                    .stroke(TimelineTheme.cardStroke, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
        .foregroundStyle(TimelineTheme.textPrimary)
    }

    private var summaryText: String {
        let settings = settingsStore.value
        return [
            sourceText,
            kindText,
            displayedItem.isAllDay ? localizer.string("timeline.section.allDay") : localizer.string("detail.timed"),
            ItemDetailAction.primaryButtonTitle(
                for: displayedItem,
                settings: settings,
                localizer: localizer
            )
        ]
        .joined(separator: " · ")
    }

    private var sourceText: String {
        switch displayedItem.source {
        case .calendar: localizer.string("source.calendar")
        case .reminder: localizer.string("source.reminders")
        case .external: "Pecker"
        }
    }

    private var kindText: String {
        switch displayedItem.kind {
        case .meeting:
            localizer.string("timeline.kind.meeting")
        case .task:
            localizer.string("timeline.kind.task")
        case .flight:
            localizer.string("timeline.kind.flight")
        case .train:
            localizer.string("timeline.kind.train")
        case .travel:
            localizer.string("timeline.kind.travel")
        case .interview:
            localizer.string("timeline.kind.interview")
        case .deadline:
            localizer.string("timeline.kind.deadline")
        case .unknown:
            localizer.string("timeline.kind.unknown")
        }
    }

    private func timingText(now: Date) -> String {
        let formatter = Date.FormatStyle()
            .locale(localizer.locale)
            .hour(.defaultDigits(amPM: .omitted))
            .minute()

        if displayedItem.isAllDay {
            return localizer.string("timeline.section.allDay")
        }

        guard let endDate = displayedItem.endDate else {
            return displayedItem.startDate.formatted(formatter)
        }

        let range = "\(displayedItem.startDate.formatted(formatter)) – \(endDate.formatted(formatter))"
        if displayedItem.startDate <= now, endDate > now {
            return "\(range) · \(localizer.string("timeline.section.active"))"
        }
        if endDate <= now {
            return "\(range) · \(localizer.string("timeline.section.elapsed"))"
        }
        return range
    }

    private func detailRow(title: String, value: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(TimelineTheme.textSecondary)
                .frame(width: 56, alignment: .leading)

            Text(value)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)

            Spacer(minLength: 0)
        }
    }

    private func togglePin() {
        let current = settingsStore.value
        settingsStore.update {
            $0 = ItemDetailAction.updatedSettings(
                byTogglingPinFor: displayedItem,
                settings: current
            )
        }
        onSettingsChanged()
    }

    private var isPinned: Bool {
        settingsStore.value.manualPinnedSourceIdentifier == displayedItem.sourceIdentifier
    }

    private var isEditable: Bool {
        timelineManager?.isEditable(displayedItem) == true
    }

    private func openEditor() {
        guard let timelineManager else {
            return
        }
        do {
            editingRecord = try timelineManager.editor(for: displayedItem)
        } catch {
            mutationError = localizer.string("editor.open.error")
        }
    }

    private func save(_ editor: TimelineRecordEditor) async throws {
        guard let timelineManager else {
            return
        }
        if let updated = try await timelineManager.save(editor) {
            displayedItem = updated
        }
    }

    private func deleteDisplayedItem() async {
        guard let timelineManager else {
            return
        }
        isDeleting = true
        defer { isDeleting = false }
        do {
            try await timelineManager.delete(displayedItem)
            dismiss()
        } catch {
            mutationError = localizer.string("delete.error")
        }
    }
}

private struct TrainTicketTemplateView: View {
    let ticket: TrainTicketTemplate
    let fallbackDepartureTime: Date
    let fallbackArrivalTime: Date?
    let localizer: AppLocalizer

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            ticketHeader

            VStack(alignment: .leading, spacing: 18) {
                routeRow
                timeRow

                if !chips.isEmpty {
                    FlowLayout(spacing: 8, lineSpacing: 8) {
                        ForEach(chips, id: \.self) { chip in
                            Text(chip)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(TimelineTheme.textPrimary)
                                .padding(.horizontal, 10)
                                .padding(.vertical, 6)
                                .background(
                                    Capsule()
                                        .fill(TimelineTheme.controlFill)
                                )
                                .overlay(
                                    Capsule()
                                        .stroke(TimelineTheme.cardStroke, lineWidth: 1)
                                )
                        }
                    }
                }
            }
            .padding(16)
        }
        .background(ticketBackground)
        .clipShape(RoundedRectangle(cornerRadius: 24, style: .continuous))
        .overlay(
            RoundedRectangle(cornerRadius: 24, style: .continuous)
                .stroke(TimelineTheme.cardStroke, lineWidth: 1)
        )
        .shadow(color: TimelineTheme.cardShadow, radius: 24, x: 0, y: 14)
        .accessibilityElement(children: .combine)
        .accessibilityLabel(accessibilityLabel)
    }

    private var ticketHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            Label {
                Text(localizer.string("train.ticket.title"))
                    .font(.subheadline.weight(.bold))
            } icon: {
                Image(systemName: "train.side.front.car")
                    .foregroundStyle(TimelineTheme.next)
            }
            .labelStyle(.titleAndIcon)

            Spacer(minLength: 8)

            Text(ticket.trainNumber ?? localizer.string("train.ticket.unknownTrain"))
                .font(.title2.weight(.black))
                .monospacedDigit()
                .foregroundStyle(
                    LinearGradient(
                        colors: [TimelineTheme.textPrimary, TimelineTheme.next],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 14)
        .background(Color.white.opacity(0.42))
    }

    private var routeRow: some View {
        HStack(alignment: .center, spacing: 12) {
            stationBlock(
                title: ticket.departureStation ?? localizer.string("train.ticket.departureStation"),
                alignment: .leading
            )

            VStack(spacing: 5) {
                Image(systemName: "arrow.right")
                    .font(.headline.weight(.bold))
                    .foregroundStyle(TimelineTheme.next)
                Rectangle()
                    .fill(TimelineTheme.next.opacity(0.55))
                    .frame(height: 1)
            }
            .frame(maxWidth: 90)

            stationBlock(
                title: ticket.arrivalStation ?? localizer.string("train.ticket.arrivalStation"),
                alignment: .trailing
            )
        }
    }

    private func stationBlock(
        title: String,
        alignment: HorizontalAlignment
    ) -> some View {
        VStack(alignment: alignment, spacing: 4) {
            Text(title)
                .font(.title3.weight(.heavy))
                .lineLimit(2)
                .minimumScaleFactor(0.82)

            Text(alignment == .leading ? "FROM" : "TO")
                .font(.caption2.weight(.bold))
                .foregroundStyle(TimelineTheme.textSecondary)
                .tracking(1.4)
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
    }

    private var timeRow: some View {
        HStack(alignment: .top, spacing: 12) {
            timeBlock(label: localizer.string("train.ticket.departure"), value: departureTimeText)
            Spacer(minLength: 12)
            timeBlock(label: localizer.string("train.ticket.arrival"), value: arrivalTimeText)
        }
    }

    private func timeBlock(label: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(label)
                .font(.caption.weight(.semibold))
                .foregroundStyle(TimelineTheme.textSecondary)
            Text(value)
                .font(.title3.weight(.bold))
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var chips: [String] {
        [
            ticket.carriageNumber.map { localizer.string("train.ticket.carriageValue", $0) },
            ticket.seatNumber.map { localizer.string("train.ticket.seatValue", $0) },
            ticket.checkInGate.map { localizer.string("train.ticket.gateValue", $0) },
            ticket.passengerName.map { localizer.string("train.ticket.passengerValue", $0) },
            ticket.ticketNumber.map { localizer.string("train.ticket.numberValue", $0) }
        ]
        .compactMap(\.self)
    }

    private var departureTimeText: String {
        ticket.departureTimeText ?? timeText(fallbackDepartureTime)
    }

    private var arrivalTimeText: String {
        if let arrivalTime = ticket.arrivalTimeText {
            return arrivalTime
        }
        guard let fallbackArrivalTime else {
            return "—"
        }
        return timeText(fallbackArrivalTime)
    }

    private var ticketBackground: some ShapeStyle {
        LinearGradient(
            colors: [
                Color(red: 1.0, green: 0.965, blue: 0.90),
                Color(red: 0.98, green: 0.915, blue: 0.84)
            ],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }

    private var accessibilityLabel: String {
        [
            localizer.string("train.ticket.title"),
            ticket.trainNumber,
            ticket.departureStation,
            ticket.arrivalStation,
            localizer.string("train.ticket.departureValue", departureTimeText),
            localizer.string("train.ticket.arrivalValue", arrivalTimeText),
            ticket.carriageNumber.map { localizer.string("train.ticket.carriageValue", $0) },
            ticket.seatNumber.map { localizer.string("train.ticket.seatValue", $0) },
            ticket.checkInGate.map { localizer.string("train.ticket.gateValue", $0) }
        ]
        .compactMap(\.self)
        .joined(separator: ", ")
    }

    private func timeText(_ date: Date) -> String {
        date.formatted(
            Date.FormatStyle()
                .hour(.defaultDigits(amPM: .omitted))
                .minute()
                .locale(localizer.locale)
        )
    }
}

private struct FlowLayout: Layout {
    let spacing: CGFloat
    let lineSpacing: CGFloat

    func sizeThatFits(
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) -> CGSize {
        let rows = rows(
            proposal: proposal,
            subviews: subviews
        )
        return CGSize(
            width: proposal.width ?? rows.map(\.width).max() ?? 0,
            height: rows.map(\.height).reduce(0, +)
                + CGFloat(max(0, rows.count - 1)) * lineSpacing
        )
    }

    func placeSubviews(
        in bounds: CGRect,
        proposal: ProposedViewSize,
        subviews: Subviews,
        cache: inout ()
    ) {
        let rows = rows(proposal: proposal, subviews: subviews)
        var y = bounds.minY
        for row in rows {
            var x = bounds.minX
            for index in row.indices {
                let size = subviews[index].sizeThatFits(.unspecified)
                subviews[index].place(
                    at: CGPoint(x: x, y: y),
                    proposal: ProposedViewSize(size)
                )
                x += size.width + spacing
            }
            y += row.height + lineSpacing
        }
    }

    private func rows(
        proposal: ProposedViewSize,
        subviews: Subviews
    ) -> [(indices: [Subviews.Index], width: CGFloat, height: CGFloat)] {
        let maxWidth = proposal.width ?? .infinity
        var rows: [(indices: [Subviews.Index], width: CGFloat, height: CGFloat)] = []
        var current: [Subviews.Index] = []
        var currentWidth: CGFloat = 0
        var currentHeight: CGFloat = 0

        for index in subviews.indices {
            let size = subviews[index].sizeThatFits(.unspecified)
            let proposedWidth = current.isEmpty
                ? size.width
                : currentWidth + spacing + size.width
            if proposedWidth > maxWidth, !current.isEmpty {
                rows.append((current, currentWidth, currentHeight))
                current = [index]
                currentWidth = size.width
                currentHeight = size.height
            } else {
                current.append(index)
                currentWidth = proposedWidth
                currentHeight = max(currentHeight, size.height)
            }
        }

        if !current.isEmpty {
            rows.append((current, currentWidth, currentHeight))
        }
        return rows
    }
}

private extension Optional where Wrapped == String {
    var nilIfEmpty: String? {
        guard let value = self?.trimmingCharacters(in: .whitespacesAndNewlines),
              !value.isEmpty
        else {
            return nil
        }
        return value
    }
}

#if DEBUG
private struct ItemDetailPreviewHost: View {
    private let settingsStore = SettingsStore(defaults: UserDefaults(suiteName: "preview.detail") ?? .standard)

    var body: some View {
        NavigationStack {
            ItemDetailView(
                item: TodayPreviewFixtures.flightItem(),
                now: TodayPreviewFixtures.makeSampleNow(),
                settingsStore: settingsStore,
                localizer: AppLocalizer(language: .english),
                onSettingsChanged: {}
            )
        }
    }
}

#Preview("Flight detail") {
    ItemDetailPreviewHost()
}

#Preview("Long notes detail") {
    NavigationStack {
        ItemDetailView(
            item: TimelineItem(
                id: "notes",
                sourceIdentifier: "notes",
                title: "Long note verification",
                startDate: TodayPreviewFixtures.makeSampleNow(),
                endDate: TodayPreviewFixtures.makeSampleNow().addingTimeInterval(45 * 60),
                isAllDay: false,
                source: .reminder,
                kind: .task,
                location: "Home office",
                notes: "This is a deliberately long note designed to make sure the detail view keeps the text readable, wraps it cleanly, and still leaves enough breathing room on large Dynamic Type settings."
            ),
            now: TodayPreviewFixtures.makeSampleNow(),
            settingsStore: SettingsStore(defaults: UserDefaults(suiteName: "preview.detail.notes") ?? .standard),
            localizer: AppLocalizer(language: .english),
            onSettingsChanged: {}
        )
        .dynamicTypeSize(.xxLarge)
    }
}

#Preview("Train ticket detail") {
    NavigationStack {
        ItemDetailView(
            item: TimelineItem(
                id: "train-ticket",
                sourceIdentifier: "train-ticket",
                title: "G123 Shanghai Hongqiao to Beijing South",
                startDate: TodayPreviewFixtures.makeSampleNow(),
                endDate: TodayPreviewFixtures.makeSampleNow().addingTimeInterval(4 * 3_600),
                isAllDay: false,
                source: .calendar,
                kind: .train,
                location: "Gate B7",
                notes: "Carriage 08, seat 03A",
                template: .trainTicket(.init(
                    trainNumber: "G123",
                    departureStation: "Shanghai Hongqiao",
                    arrivalStation: "Beijing South",
                    departureTimeText: "08:30",
                    arrivalTimeText: "13:12",
                    carriageNumber: "08",
                    seatNumber: "03A",
                    checkInGate: "B7",
                    passengerName: "Wen",
                    ticketNumber: "ETK-001"
                ))
            ),
            now: TodayPreviewFixtures.makeSampleNow(),
            settingsStore: SettingsStore(defaults: UserDefaults(suiteName: "preview.detail.train") ?? .standard),
            localizer: AppLocalizer(language: .english),
            onSettingsChanged: {}
        )
    }
}
#endif
