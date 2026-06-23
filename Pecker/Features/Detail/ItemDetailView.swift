import SwiftUI
import PeckerCore

enum ItemDetailAction {
    static func primaryButtonTitle(
        for item: TimelineItem,
        settings: TimelineSettings
    ) -> String {
        settings.manualPinnedSourceIdentifier == item.sourceIdentifier
            ? "取消固定"
            : "固定行程"
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
}

struct ItemDetailView: View {
    let item: TimelineItem
    let now: Date
    @Bindable var settingsStore: SettingsStore
    let onSettingsChanged: () -> Void

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 14) {
                header

                TimelineCard(accent: .neutral) {
                    VStack(alignment: .leading, spacing: 12) {
                        detailRow(title: "来源", value: sourceText)
                        detailRow(title: "类型", value: kindText)
                        detailRow(title: "时间", value: timingText(now: now))
                        detailRow(title: "地点", value: item.location.nilIfEmpty ?? "—")
                        detailRow(title: "备注", value: item.notes.nilIfEmpty ?? "—")
                    }
                }

                actionButton
            }
            .frame(maxWidth: 760, alignment: .leading)
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
        }
        .background(TimelineTheme.backgroundGradient.ignoresSafeArea())
        .foregroundStyle(TimelineTheme.textPrimary)
        .navigationTitle(Self.navigationTitle)
        .navigationBarTitleDisplayMode(.inline)
    }

    static let navigationTitle = "详情"

    private var header: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(item.title)
                .font(.largeTitle.weight(.bold))
                .fixedSize(horizontal: false, vertical: true)

            Text(summaryText)
                .font(.subheadline)
                .foregroundStyle(TimelineTheme.textSecondary)
        }
    }

    private var actionButton: some View {
        Button {
            togglePin()
        } label: {
            TimelineCard(accent: settingsStore.value.manualPinnedSourceIdentifier == item.sourceIdentifier ? .pinned : .neutral) {
                HStack(alignment: .center, spacing: 12) {
                    Image(systemName: settingsStore.value.manualPinnedSourceIdentifier == item.sourceIdentifier ? "pin.fill" : "pin")
                        .foregroundStyle(settingsStore.value.manualPinnedSourceIdentifier == item.sourceIdentifier ? TimelineTheme.color(for: .pinned) : TimelineTheme.textPrimary)
                    Text(ItemDetailAction.primaryButtonTitle(for: item, settings: settingsStore.value))
                        .font(.headline.weight(.semibold))
                    Spacer(minLength: 8)
                }
            }
        }
        .buttonStyle(.plain)
    }

    private var summaryText: String {
        let settings = settingsStore.value
        return [
            item.source == .calendar ? "日历" : "提醒事项",
            kindText,
            item.isAllDay ? "全天" : "定时",
            ItemDetailAction.primaryButtonTitle(for: item, settings: settings)
        ]
        .joined(separator: " · ")
    }

    private var sourceText: String {
        item.source == .calendar ? "日历" : "提醒事项"
    }

    private var kindText: String {
        switch item.kind {
        case .meeting:
            "会议"
        case .task:
            "待办"
        case .flight:
            "航班"
        case .train:
            "火车"
        case .travel:
            "行程"
        case .interview:
            "面试"
        case .deadline:
            "截止"
        case .unknown:
            "未分类"
        }
    }

    private func timingText(now: Date) -> String {
        let formatter = Date.FormatStyle()
            .locale(Locale(identifier: "zh_CN"))
            .hour(.defaultDigits(amPM: .omitted))
            .minute()

        if item.isAllDay {
            return "全天"
        }

        guard let endDate = item.endDate else {
            return item.startDate.formatted(formatter)
        }

        let range = "\(item.startDate.formatted(formatter)) – \(endDate.formatted(formatter))"
        if item.startDate <= now, endDate > now {
            return "\(range) · 进行中"
        }
        if endDate <= now {
            return "\(range) · 已结束"
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
                byTogglingPinFor: item,
                settings: current
            )
        }
        onSettingsChanged()
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
            onSettingsChanged: {}
        )
        .dynamicTypeSize(.xxLarge)
    }
}
#endif
