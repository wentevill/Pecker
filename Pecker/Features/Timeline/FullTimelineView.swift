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
                            ProgressView("加载时间线…")
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
            .navigationTitle(activeOnly ? "进行中" : "完整时间线")
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
            "删除这个事件？",
            isPresented: Binding(
                get: { pendingDelete != nil },
                set: { if !$0 { pendingDelete = nil } }
            ),
            titleVisibility: .visible
        ) {
            Button("删除", role: .destructive) {
                guard let item = pendingDelete else { return }
                pendingDelete = nil
                Task {
                    do {
                        try await model.delete(item)
                    } catch {
                        mutationError = "删除失败，请稍后重试。"
                    }
                }
            }
            Button("取消", role: .cancel) {
                pendingDelete = nil
            }
        }
        .alert(
            "操作失败",
            isPresented: Binding(
                get: { mutationError != nil },
                set: { if !$0 { mutationError = nil } }
            )
        ) {
            Button("好") { mutationError = nil }
        } message: {
            Text(mutationError ?? "")
        }
    }

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(activeOnly ? "进行中项目" : scopeTitle)
                .font(.largeTitle.weight(.bold))
                .foregroundStyle(TimelineTheme.textPrimary)

            Text(headerSubtitle)
                .font(.subheadline)
                .foregroundStyle(TimelineTheme.textSecondary)
        }
    }

    private var headerSubtitle: String {
        if activeOnly {
            return "来自当前快照的所有进行中项目。"
        }

        return "按时间与类型管理日历、提醒事项和 Pecker 卡片。"
    }

    private var scopeTitle: String {
        switch model.selectedScope {
        case .today: "今日时间线"
        case .future: "未来时间线"
        case .history: "历史时间线"
        }
    }

    private var scopeControl: some View {
        Picker("时间范围", selection: $model.selectedScope) {
            Text("今日").tag(TimelineDateScope.today)
            Text("未来").tag(TimelineDateScope.future)
            Text("历史").tag(TimelineDateScope.history)
        }
        .pickerStyle(.segmented)
        .onChange(of: model.selectedScope) { _, scope in
            Task { await model.setScope(scope) }
        }
    }

    private var kindFilters: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                kindButton(title: "全部", kind: nil)
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
                Text(activeOnly ? "当前没有进行中的项目" : "当前没有可显示的项目")
                    .font(.headline.weight(.semibold))
                Text("可以下拉刷新，或者稍后再看。")
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
        HStack(alignment: .top, spacing: 12) {
            Button {
                onSelectItem(item)
            } label: {
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
                }
            }
            .buttonStyle(.plain)
            .accessibilityLabel(accessibilityLabel(for: item, section: section, now: now))

            Button {
                onTogglePin(item)
            } label: {
                Image(systemName: pinSymbol(for: item))
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(pinTint(for: item))
                    .frame(width: 34, height: 34)
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
                        Label("编辑", systemImage: "pencil")
                    }
                    Button(role: .destructive) {
                        pendingDelete = item
                    } label: {
                        Label("删除", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis")
                        .frame(width: 34, height: 34)
                        .background(Circle().fill(TimelineTheme.controlFill))
                        .overlay(Circle().stroke(TimelineTheme.cardStroke))
                }
            }
        }
        .contextMenu {
            if model.isEditable(item) {
                Button {
                    openEditor(for: item)
                } label: {
                    Label("编辑", systemImage: "pencil")
                }

                Button(role: .destructive) {
                    pendingDelete = item
                } label: {
                    Label("删除", systemImage: "trash")
                }
            }
        }
    }

    private func openEditor(for item: TimelineItem) {
        do {
            editingRecord = try model.editor(for: item)
            isEditorPresented = true
        } catch {
            mutationError = "无法打开编辑器。"
        }
    }

    private func sourceTitle(for item: TimelineItem) -> String {
        switch item.source {
        case .calendar: "日历"
        case .reminder: "提醒事项"
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
        case .meeting: "会议"
        case .task: "任务"
        case .flight: "航班"
        case .train: "火车"
        case .travel: "行程"
        case .interview: "面试"
        case .deadline: "截止"
        case .unknown: "未分类"
        }
    }

    private func statusText(for section: TimelineGrouping.Section.Kind, item: TimelineItem) -> String {
        switch section {
        case .overdue:
            "已逾期"
        case .allDay:
            "全天"
        case .active:
            "进行中"
        case .upcoming:
            "即将开始"
        case .elapsed:
            "已结束"
        }
    }

    private func timeText(for item: TimelineItem, now: Date) -> String {
        let formatter = Date.FormatStyle()
            .hour(.defaultDigits(amPM: .omitted))
            .minute()
            .locale(Locale(identifier: "zh_CN"))

        if item.isAllDay {
            return "全天"
        }

        guard let end = item.endDate else {
            return item.startDate.formatted(formatter)
        }

        let range = "\(item.startDate.formatted(formatter)) – \(end.formatted(formatter))"
        if item.endDate.map({ $0 > now }) == true, item.startDate <= now {
            return "\(range) · 进行中"
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
            ? "取消固定"
            : "固定行程"
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
