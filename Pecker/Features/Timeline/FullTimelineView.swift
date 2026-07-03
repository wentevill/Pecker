import SwiftUI
import PeckerCore

struct FullTimelineView: View {
    @Bindable var model: TimelineManagerModel
    let now: Date
    let settings: TimelineSettings
    let localizer: AppLocalizer
    let activeOnly: Bool
    let onSelectItem: (TimelineItem) -> Void
    let onTogglePin: (TimelineItem) -> Void
    let onOpenSettings: () -> Void
    @State private var pendingDelete: TimelineItem?
    @State private var mutationError: String?

    init(
        model: TimelineManagerModel,
        now: Date,
        settings: TimelineSettings,
        localizer: AppLocalizer = AppLocalizer(language: .system),
        activeOnly: Bool,
        onSelectItem: @escaping (TimelineItem) -> Void,
        onTogglePin: @escaping (TimelineItem) -> Void,
        onOpenSettings: @escaping () -> Void
    ) {
        self.model = model
        self.now = now
        self.settings = settings
        self.localizer = localizer
        self.activeOnly = activeOnly
        self.onSelectItem = onSelectItem
        self.onTogglePin = onTogglePin
        self.onOpenSettings = onOpenSettings
    }

    var body: some View {
        TimelineView(.periodic(from: now, by: 60)) { context in
            let sections = TimelineGrouping.sections(
                items: displayedItems(at: context.date),
                now: context.date,
                activeOnly: activeOnly,
                localizer: localizer
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
                            ProgressView(localizer.string("timeline.loading"))
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
            .navigationTitle(activeOnly ? localizer.string("timeline.active.title") : localizer.string("timeline.full.title"))
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: onOpenSettings) {
                        Image(systemName: "gearshape.fill")
                    }
                }
            }
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
                        try await model.delete(item)
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
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(activeOnly ? localizer.string("timeline.active.items") : scopeTitle)
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(TimelineTheme.textPrimary)

            Text(headerSubtitle)
                .font(.subheadline)
                .foregroundStyle(TimelineTheme.textSecondary)
        }
    }

    private var headerSubtitle: String {
        if activeOnly {
            return localizer.string("timeline.active.subtitle")
        }

        return localizer.string("timeline.full.subtitle")
    }

    private var scopeTitle: String {
        switch model.selectedScope {
        case .today: localizer.string("timeline.scope.today.title")
        case .future: localizer.string("timeline.scope.future.title")
        case .history: localizer.string("timeline.scope.history.title")
        }
    }

    private var scopeControl: some View {
        Picker(localizer.string("timeline.scope.label"), selection: $model.selectedScope) {
            Text(localizer.string("timeline.scope.today")).tag(TimelineDateScope.today)
            Text(localizer.string("timeline.scope.future")).tag(TimelineDateScope.future)
            Text(localizer.string("timeline.scope.history")).tag(TimelineDateScope.history)
        }
        .pickerStyle(.segmented)
        .onChange(of: model.selectedScope) { _, scope in
            Task { await model.setScope(scope) }
        }
    }

    private var kindFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                kindButton(title: localizer.string("timeline.kind.all"), kind: nil)
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
                Text(activeOnly ? localizer.string("timeline.empty.active") : localizer.string("timeline.empty.full"))
                    .font(.headline.weight(.semibold))
                Text(localizer.string("timeline.empty.body"))
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
            onTap: { onSelectItem(item) },
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
                    }

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
            }
        }
        .accessibilityLabel(accessibilityLabel(for: item, section: section, now: now))
    }

    private func sourceTitle(for item: TimelineItem) -> String {
        switch item.source {
        case .calendar: localizer.string("source.calendar")
        case .reminder: localizer.string("source.reminders")
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
        case .meeting: localizer.string("timeline.kind.meeting")
        case .task: localizer.string("timeline.kind.task")
        case .flight: localizer.string("timeline.kind.flight")
        case .train: localizer.string("timeline.kind.train")
        case .travel: localizer.string("timeline.kind.travel")
        case .interview: localizer.string("timeline.kind.interview")
        case .deadline: localizer.string("timeline.kind.deadline")
        case .unknown: localizer.string("timeline.kind.unknown")
        }
    }

    private func statusText(for section: TimelineGrouping.Section.Kind, item: TimelineItem) -> String {
        switch section {
        case .overdue:
            localizer.string("timeline.section.overdue")
        case .allDay:
            localizer.string("timeline.section.allDay")
        case .active:
            localizer.string("timeline.section.active")
        case .upcoming:
            localizer.string("timeline.section.upcoming")
        case .elapsed:
            localizer.string("timeline.section.elapsed")
        }
    }

    private func timeText(for item: TimelineItem, now: Date) -> String {
        let formatter = Date.FormatStyle()
            .hour(.defaultDigits(amPM: .omitted))
            .minute()
            .locale(localizer.locale)

        if item.isAllDay {
            return localizer.string("timeline.section.allDay")
        }

        guard let end = item.endDate else {
            return item.startDate.formatted(formatter)
        }

        let range = "\(item.startDate.formatted(formatter)) – \(end.formatted(formatter))"
        if item.endDate.map({ $0 > now }) == true, item.startDate <= now {
            return "\(range) · \(localizer.string("timeline.section.active"))"
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
            ? localizer.string("pin.action.unpin")
            : localizer.string("pin.action.pin")
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
        .joined(separator: ", ")
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
