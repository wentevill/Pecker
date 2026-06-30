import SwiftUI
import PeckerCore

struct FullTimelineView: View {
    @Bindable var model: TimelineManagerModel
    let now: Date
    let settings: TimelineSettings
    let activeOnly: Bool
    let onSelectItem: (TimelineItem) -> Void
    let onTogglePin: (TimelineItem) -> Void
    let onOpenSettings: () -> Void
    @State private var editingRecord: TimelineRecordEditor?
    @State private var isEditorPresented = false
    @State private var pendingDelete: TimelineItem?
    @State private var mutationError: String?

    var body: some View {
        TimelineView(.periodic(from: now, by: 60)) { context in
            let sections = TimelineGrouping.sections(
                items: displayedItems(at: context.date),
                now: context.date,
                activeOnly: activeOnly
            )

            ZStack {
                TimelineTheme.backgroundGradient
                    .ignoresSafeArea()

                ScrollView {
                    VStack(alignment: .leading, spacing: 14) {
                        header
                        scopeControl
                        kindFilters

                        if model.isLoading && model.items.isEmpty {
                            ProgressView("\u{52a0}\u{8f7d}\u{65f6}\u{95f4}\u{7ebf}…")
                                .frame(maxWidth: .infinity)
                                .padding(30)
                        } else if sections.isEmpty {
                            emptyState
                        } else {
                            ForEach(sections) { section in
                                sectionView(section, now: context.date)
                            }
                        }
                    }
                    .frame(maxWidth: 760, alignment: .leading)
                    .padding(.horizontal, 16)
                    .padding(.vertical, 14)
                }
            }
            .task {
                await model.load(now: context.date)
            }
            .foregroundStyle(TimelineTheme.textPrimary)
            .navigationTitle(activeOnly ? "\u{8fdb}\u{884c}\u{4e2d}" : "\u{5b8c}\u{6574}\u{65f6}\u{95f4}\u{7ebf}")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: onOpenSettings) {
                        Image(systemName: "gearshape.fill")
                    }
                }
            }
        }
        .sheet(isPresented: $isEditorPresented) {
            if let editingRecord {
                TimelineRecordEditorView(editor: editingRecord) { editor in
                    try await model.save(editor)
                }
            }
        }
        .confirmationDialog(
            "\u{5220}\u{9664}\u{8fd9}\u{4e2a}\u{4e8b}\u{4ef6}？",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("\u{5220}\u{9664}", role: .destructive) {
                guard let item = pendingDelete else { return }
                pendingDelete = nil
                Task {
                    do {
                        try await model.delete(item)
                    } catch {
                        mutationError = "\u{5220}\u{9664}\u{5931}\u{8d25}，\u{8bf7}\u{7a0d}\u{540e}\u{91cd}\u{8bd5}。"
                    }
                }
            }
            Button("\u{53d6}\u{6d88}", role: .cancel) {
                pendingDelete = nil
            }
        }
        .alert(
            "\u{64cd}\u{4f5c}\u{5931}\u{8d25}",
            isPresented: Binding(
                get: { mutationError != nil },
                set: { if !$0 { mutationError = nil } }
            )
        ) {
            Button("\u{597d}") { mutationError = nil }
        } message: {
            Text(mutationError ?? "")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(activeOnly ? "\u{8fdb}\u{884c}\u{4e2d}\u{9879}\u{76ee}" : scopeTitle)
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(TimelineTheme.textPrimary)

            Text(headerSubtitle)
                .font(.subheadline)
                .foregroundStyle(TimelineTheme.textSecondary)
        }
    }

    private var headerSubtitle: String {
        if activeOnly {
            return "\u{6765}\u{81ea}\u{5f53}\u{524d}\u{5feb}\u{7167}\u{7684}\u{6240}\u{6709}\u{8fdb}\u{884c}\u{4e2d}\u{9879}\u{76ee}。"
        }

        return "\u{6309}\u{65f6}\u{95f4}\u{4e0e}\u{7c7b}\u{578b}\u{7ba1}\u{7406}\u{65e5}\u{5386}、\u{63d0}\u{9192}\u{4e8b}\u{9879}\u{548c} Pecker \u{5361}\u{7247}。"
    }

    private var scopeTitle: String {
        switch model.selectedScope {
        case .today: "\u{4eca}\u{65e5}\u{65f6}\u{95f4}\u{7ebf}"
        case .future: "\u{672a}\u{6765}\u{65f6}\u{95f4}\u{7ebf}"
        case .history: "\u{5386}\u{53f2}\u{65f6}\u{95f4}\u{7ebf}"
        }
    }

    private var scopeControl: some View {
        Picker("\u{65f6}\u{95f4}\u{8303}\u{56f4}", selection: $model.selectedScope) {
            Text("\u{4eca}\u{65e5}").tag(TimelineDateScope.today)
            Text("\u{672a}\u{6765}").tag(TimelineDateScope.future)
            Text("\u{5386}\u{53f2}").tag(TimelineDateScope.history)
        }
        .pickerStyle(.segmented)
        .onChange(of: model.selectedScope) { _, scope in
            Task { await model.setScope(scope) }
        }
    }

    private var kindFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                kindButton(title: "\u{5168}\u{90e8}", kind: nil)
                ForEach(TimelineKind.allCases, id: \.self) { kind in
                    kindButton(title: kindTitle(kind), kind: kind)
                }
            }
        }
    }

    private func kindButton(
        title: String,
        kind: TimelineKind?
    ) -> some View {
        Button {
            model.selectedKind = kind
        } label: {
            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(
                    model.selectedKind == kind
                        ? TimelineTheme.textPrimary
                        : TimelineTheme.textSecondary
                )
                .padding(.horizontal, 13)
                .padding(.vertical, 8)
                .background(
                    Capsule().fill(
                        model.selectedKind == kind
                            ? TimelineTheme.controlFill
                            : Color.white.opacity(0.28)
                    )
                )
                .overlay(Capsule().stroke(TimelineTheme.cardStroke))
        }
        .buttonStyle(.plain)
    }

    private func displayedItems(at now: Date) -> [TimelineItem] {
        guard activeOnly else {
            return model.visibleItems
        }
        return model.visibleItems.filter {
            $0.startDate <= now && ($0.endDate ?? $0.startDate) > now
        }
    }

    private var emptyState: some View {
        TimelineCard(accent: .neutral) {
            VStack(alignment: .leading, spacing: 12) {
                Text(activeOnly ? "\u{5f53}\u{524d}\u{6ca1}\u{6709}\u{8fdb}\u{884c}\u{4e2d}\u{7684}\u{9879}\u{76ee}" : "\u{5f53}\u{524d}\u{6ca1}\u{6709}\u{53ef}\u{663e}\u{793a}\u{7684}\u{9879}\u{76ee}")
                    .font(.headline.weight(.semibold))
                Text("\u{53ef}\u{4ee5}\u{4e0b}\u{62c9}\u{5237}\u{65b0}，\u{6216}\u{8005}\u{7a0d}\u{540e}\u{518d}\u{770b}。")
                    .font(.body)
                    .foregroundStyle(TimelineTheme.textSecondary)
            }
        }
    }

    private func sectionView(
        _ section: TimelineGrouping.Section,
        now: Date
    ) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            Text(section.title)
                .font(.headline.weight(.semibold))
                .foregroundStyle(TimelineTheme.textSecondary)
                .padding(.horizontal, 4)

            VStack(alignment: .leading, spacing: 10) {
                ForEach(section.items) { item in
                    timelineRow(item: item, section: section, now: now)
                }
            }
        }
    }

    private func timelineRow(
        item: TimelineItem,
        section: TimelineGrouping.Section,
        now: Date
    ) -> some View {
        SwipeDeleteAction(
            isEnabled: model.isEditable(item),
            onDelete: { pendingDelete = item }
        ) {
            TimelineCard(accent: accent(for: section.kind, item: item)) {
                VStack(alignment: .leading, spacing: 10) {
                    HStack(alignment: .center, spacing: 10) {
                        Label {
                            Text(sourceTitle(for: item))
                        } icon: {
                            Image(systemName: sourceSymbol(for: item))
                        }
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(TimelineTheme.textSecondary)
                        .labelStyle(.titleAndIcon)

                        Spacer(minLength: 8)

                        Text(statusText(for: section.kind, item: item))
                            .font(.caption.weight(.semibold))
                            .foregroundStyle(TimelineTheme.color(for: accent(for: section.kind, item: item)))

                        timelineActions(for: item)
                    }

                    Button {
                        onSelectItem(item)
                    } label: {
                        VStack(alignment: .leading, spacing: 10) {
                            Text(item.title)
                                .font(.title3.weight(.semibold))
                                .lineLimit(nil)
                                .fixedSize(horizontal: false, vertical: true)

                            Text(timeText(for: item, now: now))
                                .font(.subheadline.weight(.medium))
                                .foregroundStyle(TimelineTheme.textSecondary)
                                .fixedSize(horizontal: false, vertical: true)

                            if let detailText = detailText(for: item) {
                                Text(detailText)
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(TimelineTheme.textPrimary)
                                    .fixedSize(horizontal: false, vertical: true)
                            }
                        }
                        .frame(maxWidth: .infinity, alignment: .leading)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .accessibilityLabel(accessibilityLabel(for: item, section: section, now: now))
        .contextMenu {
            if model.isEditable(item) {
                Button {
                    openEditor(for: item)
                } label: {
                    Label("\u{7f16}\u{8f91}", systemImage: "pencil")
                }

                Button(role: .destructive) {
                    pendingDelete = item
                } label: {
                    Label("\u{5220}\u{9664}", systemImage: "trash")
                }
            }
        }
    }

    @ViewBuilder
    private func timelineActions(for item: TimelineItem) -> some View {
        Button {
            onTogglePin(item)
        } label: {
            Image(systemName: pinSymbol(for: item))
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(pinTint(for: item))
                .frame(width: 32, height: 32)
                .background(Circle().fill(TimelineTheme.controlFill))
                .overlay(Circle().stroke(TimelineTheme.cardStroke, lineWidth: 1))
        }
        .buttonStyle(.plain)
        .accessibilityLabel(pinAccessibilityLabel(for: item))

        if model.isEditable(item) {
            Menu {
                Button {
                    openEditor(for: item)
                } label: {
                    Label("\u{7f16}\u{8f91}", systemImage: "pencil")
                }
                Button(role: .destructive) {
                    pendingDelete = item
                } label: {
                    Label("\u{5220}\u{9664}", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis")
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(TimelineTheme.textSecondary)
                    .frame(width: 32, height: 32)
                    .background(Circle().fill(TimelineTheme.controlFill))
                    .overlay(Circle().stroke(TimelineTheme.cardStroke))
            }
            .accessibilityLabel("\u{66f4}\u{591a}\u{64cd}\u{4f5c}")
        }
    }

    private func openEditor(for item: TimelineItem) {
        do {
            editingRecord = try model.editor(for: item)
            isEditorPresented = true
        } catch {
            mutationError = "\u{65e0}\u{6cd5}\u{6253}\u{5f00}\u{7f16}\u{8f91}\u{5668}。"
        }
    }

    private func sourceTitle(for item: TimelineItem) -> String {
        switch item.source {
        case .calendar: "\u{65e5}\u{5386}"
        case .reminder: "\u{63d0}\u{9192}\u{4e8b}\u{9879}"
        case .external: "Pecker"
        }
    }

    private func sourceSymbol(for item: TimelineItem) -> String {
        switch item.source {
        case .calendar: "calendar"
        case .reminder: "checklist"
        case .external: "sparkles.rectangle.stack"
        }
    }

    private func kindTitle(_ kind: TimelineKind) -> String {
        switch kind {
        case .meeting: "\u{4f1a}\u{8bae}"
        case .task: "\u{4efb}\u{52a1}"
        case .flight: "\u{822a}\u{73ed}"
        case .train: "\u{706b}\u{8f66}"
        case .travel: "\u{884c}\u{7a0b}"
        case .interview: "\u{9762}\u{8bd5}"
        case .deadline: "\u{622a}\u{6b62}"
        case .unknown: "\u{672a}\u{5206}\u{7c7b}"
        }
    }

    private func statusText(for section: TimelineGrouping.Section.Kind, item: TimelineItem) -> String {
        switch section {
        case .overdue:
            "\u{5df2}\u{903e}\u{671f}"
        case .allDay:
            "\u{5168}\u{5929}"
        case .active:
            "\u{8fdb}\u{884c}\u{4e2d}"
        case .upcoming:
            "\u{5373}\u{5c06}\u{5f00}\u{59cb}"
        case .elapsed:
            "\u{5df2}\u{7ed3}\u{675f}"
        }
    }

    private func timeText(for item: TimelineItem, now: Date) -> String {
        let formatter = Date.FormatStyle()
            .hour(.defaultDigits(amPM: .omitted))
            .minute()
            .locale(Locale(identifier: "zh_CN"))

        if item.isAllDay {
            return "\u{5168}\u{5929}"
        }

        guard let end = item.endDate else {
            return item.startDate.formatted(formatter)
        }

        let range = "\(item.startDate.formatted(formatter)) – \(end.formatted(formatter))"
        if item.endDate.map({ $0 > now }) == true, item.startDate <= now {
            return "\(range) · \u{8fdb}\u{884c}\u{4e2d}"
        }

        return range
    }

    private func detailText(for item: TimelineItem) -> String? {
        let location = item.location?.trimmingCharacters(in: .whitespacesAndNewlines)
        let notes = item.notes?.trimmingCharacters(in: .whitespacesAndNewlines)
        if let location, !location.isEmpty {
            return location
        }
        if let notes, !notes.isEmpty {
            return notes
        }
        return nil
    }

    private func accent(
        for kind: TimelineGrouping.Section.Kind,
        item: TimelineItem
    ) -> TimelineAccent {
        if settings.manualPinnedSourceIdentifier == item.sourceIdentifier {
            return .pinned
        }

        switch kind {
        case .active:
            return .now
        case .upcoming:
            return .next
        case .overdue, .allDay, .elapsed:
            return item.source == .reminder ? .neutral : .next
        }
    }

    private func pinSymbol(for item: TimelineItem) -> String {
        settings.manualPinnedSourceIdentifier == item.sourceIdentifier ? "pin.fill" : "pin"
    }

    private func pinTint(for item: TimelineItem) -> Color {
        settings.manualPinnedSourceIdentifier == item.sourceIdentifier
            ? TimelineTheme.color(for: .pinned)
            : TimelineTheme.textSecondary
    }

    private func pinAccessibilityLabel(for item: TimelineItem) -> String {
        settings.manualPinnedSourceIdentifier == item.sourceIdentifier
            ? "\u{53d6}\u{6d88}\u{56fa}\u{5b9a}"
            : "\u{56fa}\u{5b9a}\u{884c}\u{7a0b}"
    }

    private func accessibilityLabel(
        for item: TimelineItem,
        section: TimelineGrouping.Section,
        now: Date
    ) -> String {
        [
            sourceTitle(for: item),
            section.title,
            item.title,
            timeText(for: item, now: now),
            detailText(for: item) ?? "",
            pinAccessibilityLabel(for: item)
        ]
        .filter { !$0.isEmpty }
        .joined(separator: "，")
    }
}

#if PREVIEW_FIXTURES
private struct FullTimelinePreviewHost: View {
    private let snapshot = FullTimelinePreviewData.snapshot()
    private let settings = FullTimelinePreviewData.settings(pinnedIdentifier: "pinned")

    var body: some View {
        NavigationStack {
            FullTimelineView(
                snapshot: snapshot,
                now: FullTimelinePreviewData.now,
                settings: settings,
                activeOnly: false,
                onSelectItem: { _ in },
                onTogglePin: { _ in },
                onOpenSettings: {}
            )
        }
    }
}

private enum FullTimelinePreviewData {
    static let now: Date = {
        var components = DateComponents()
        components.calendar = calendar
        components.timeZone = calendar.timeZone
        components.year = 2025
        components.month = 5
        components.day = 20
        components.hour = 9
        components.minute = 48
        return components.date ?? .now
    }()

    static func snapshot() -> TodaySnapshot {
        TodaySnapshot(
            schemaVersion: TodaySnapshot.currentSchemaVersion,
            generatedAt: now,
            staleAfter: now.addingTimeInterval(30 * 60),
            items: [
                item(id: "overdue", title: "Overdue Reminder", start: now.addingTimeInterval(-3 * 3_600), end: now.addingTimeInterval(-2 * 3_600), source: .reminder, kind: .task),
                item(id: "all-day", title: "All-day conference", start: now, end: now.addingTimeInterval(24 * 3_600), source: .calendar, kind: .travel, isAllDay: true),
                item(id: "active", title: "Design review", start: now.addingTimeInterval(-25 * 60), end: now.addingTimeInterval(20 * 60), source: .calendar, kind: .meeting),
                item(id: "upcoming", title: "Flight to Singapore", start: now.addingTimeInterval(2 * 3_600), end: now.addingTimeInterval(4 * 3_600), source: .calendar, kind: .flight, location: "T3 · Gate B7"),
                item(id: "elapsed", title: "Morning standup", start: now.addingTimeInterval(-8 * 3_600), end: now.addingTimeInterval(-7 * 3_600), source: .calendar, kind: .meeting)
            ],
            nowItemID: "active",
            concurrentNowCount: 2,
            nextItemID: "upcoming",
            pinnedItemID: "upcoming",
            pinOrigin: .manual
        )
    }

    static func settings(pinnedIdentifier: String?) -> TimelineSettings {
        var settings = TimelineSettings()
        settings.manualPinnedSourceIdentifier = pinnedIdentifier
        return settings
    }

    private static func item(
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

    private static var calendar: Calendar {
        var calendar = Calendar(identifier: .gregorian)
        calendar.locale = Locale(identifier: "zh_CN")
        calendar.timeZone = .init(secondsFromGMT: 8 * 3_600) ?? .current
        return calendar
    }
}

#Preview("Full timeline") {
    FullTimelinePreviewHost()
}

#Preview("Active only") {
    NavigationStack {
        FullTimelineView(
            snapshot: FullTimelinePreviewData.snapshot(),
            now: FullTimelinePreviewData.now,
            settings: FullTimelinePreviewData.settings(pinnedIdentifier: nil),
            activeOnly: true,
            onSelectItem: { _ in },
            onTogglePin: { _ in },
            onOpenSettings: {}
        )
    }
}
#endif
