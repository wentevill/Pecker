import ActivityKit
import SwiftUI
import WidgetKit

struct DynamicIslandLiveActivityView {
    private let state: PeckerActivityAttributes.ContentState

    init(context: ActivityViewContext<PeckerActivityAttributes>) {
        self.state = context.state
    }

    init(state: PeckerActivityAttributes.ContentState) {
        self.state = state
    }

    var body: DynamicIsland {
        DynamicIsland {
            DynamicIslandExpandedRegion(.leading) {
                ExpandedPrimaryItem(state: state)
            }

            DynamicIslandExpandedRegion(.trailing) {
                ExpandedCountdown(state: state)
            }

            DynamicIslandExpandedRegion(.bottom) {
                ExpandedBottom(state: state)
            }
        } compactLeading: {
            CompactLeading(state: state)
        } compactTrailing: {
            CompactTrailing(state: state)
        } minimal: {
            MinimalIsland(state: state)
        }
        .keylineTint(statusColor)
    }

    private var statusColor: Color {
        DynamicIslandStyle.statusColor(for: state)
    }
}

private struct CompactLeading: View {
    @Environment(\.locale) private var locale
    let state: PeckerActivityAttributes.ContentState

    var body: some View {
        if let title = DynamicIslandStyle.compactTitle(for: state.primaryTitle) {
            Text(title)
                .font(.caption2.weight(.heavy))
                .foregroundStyle(DynamicIslandStyle.statusColor(for: state))
                .lineLimit(1)
                .minimumScaleFactor(0.72)
        } else {
            StatusDot(color: DynamicIslandStyle.statusColor(for: state))
                .accessibilityLabel(DynamicIslandStyle.statusLabel(for: state, locale: locale))
        }
    }
}

private struct CompactTrailing: View {
    @Environment(\.locale) private var locale
    let state: PeckerActivityAttributes.ContentState

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { timeline in
            if let targetDate = state.countdownTargetDate(at: timeline.date) {
                RemainingMinutesText(
                    targetDate: targetDate,
                    font: .caption2.weight(.bold).monospacedDigit()
                )
                    .foregroundStyle(PeckerLiveActivityPalette.textPrimary.color)
            } else {
                Text(DynamicIslandStyle.statusLabel(for: state, locale: locale))
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(PeckerLiveActivityPalette.textPrimary.color)
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
            }
        }
    }
}

private struct MinimalIsland: View {
    let state: PeckerActivityAttributes.ContentState

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { timeline in
            if let targetDate = state.countdownTargetDate(at: timeline.date) {
                RemainingMinutesText(
                    targetDate: targetDate,
                    font: .caption2.weight(.heavy).monospacedDigit()
                )
                    .foregroundStyle(DynamicIslandStyle.statusColor(for: state))
                    .minimumScaleFactor(0.66)
            } else {
                StatusDot(color: DynamicIslandStyle.statusColor(for: state), size: 8)
            }
        }
    }
}

private struct ExpandedPrimaryItem: View {
    @Environment(\.locale) private var locale
    let state: PeckerActivityAttributes.ContentState

    var body: some View {
        HStack(alignment: .top, spacing: 8) {
            StatusDot(color: DynamicIslandStyle.statusColor(for: state), size: 9)
                .padding(.top, 4)

            VStack(alignment: .leading, spacing: 3) {
                Text(DynamicIslandStyle.statusLabel(for: state, locale: locale))
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(DynamicIslandStyle.statusColor(for: state))

                Text(state.primaryTitle)
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(PeckerLiveActivityPalette.textPrimary.color)
                    .lineLimit(2)
                    .minimumScaleFactor(0.78)

                if let subtitle = state.primarySubtitle, !subtitle.isEmpty {
                    Text(subtitle)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(PeckerLiveActivityPalette.textSecondary.color)
                        .lineLimit(1)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

private struct ExpandedCountdown: View {
    @Environment(\.locale) private var locale
    let state: PeckerActivityAttributes.ContentState

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { timeline in
            VStack(alignment: .trailing, spacing: 3) {
                if let targetDate = state.countdownTargetDate(at: timeline.date) {
                    Text(targetDate, style: state.isPrimaryRunning(at: timeline.date) ? .timer : .relative)
                        .font(.title3.weight(.bold).monospacedDigit())
                        .foregroundStyle(PeckerLiveActivityPalette.textPrimary.color)
                        .lineLimit(1)
                        .minimumScaleFactor(0.72)

                    Text(
                        PeckerLiveActivityCopy.countdownHint(
                            isRunning: state.isPrimaryRunning(at: timeline.date),
                            locale: locale
                        )
                    )
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(PeckerLiveActivityPalette.textSecondary.color)
                } else {
                    Text(DynamicIslandStyle.statusLabel(for: state, locale: locale))
                        .font(.caption.weight(.heavy))
                        .foregroundStyle(DynamicIslandStyle.statusColor(for: state))
                        .lineLimit(1)
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }
}

private struct ExpandedBottom: View {
    @Environment(\.locale) private var locale
    let state: PeckerActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 7) {
            if let nextTitle = state.nextTitle, !nextTitle.isEmpty, !isNextPrimary {
                NextRow(title: nextTitle, startDate: state.nextStartDate)
            }

            TimelineView(.periodic(from: .now, by: 30)) { timeline in
                if state.isPrimaryRunning(at: timeline.date) {
                    DynamicIslandProgressBar(
                        startDate: state.primaryStartDate,
                        endDate: state.primaryEndDate,
                        accent: DynamicIslandStyle.statusColor(for: state)
                    )
                }
            }

            if state.additionalActiveCount > 0 {
                Text(
                    PeckerLiveActivityCopy.additionalActiveText(
                        count: state.additionalActiveCount,
                        locale: locale
                    )
                )
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(PeckerLiveActivityPalette.textSecondary.color)
                    .lineLimit(1)
            }
        }
        .padding(.top, 2)
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var isNextPrimary: Bool {
        state.primaryTitle == state.nextTitle
            || (state.primaryEndDate == nil && state.primaryStartDate != nil)
    }
}

private struct NextRow: View {
    @Environment(\.locale) private var locale
    let title: String
    let startDate: Date?

    var body: some View {
        HStack(spacing: 6) {
            Text(PeckerLiveActivityCopy.statusLabel(for: .next, locale: locale))
                .font(.caption2.weight(.heavy))
                .foregroundStyle(DynamicIslandStyle.statusColor(for: .next))

            Text(title)
                .font(.caption.weight(.semibold))
                .foregroundStyle(PeckerLiveActivityPalette.textPrimary.color)
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Spacer(minLength: 4)

            if let startDate {
                Text(startDate, style: .relative)
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(PeckerLiveActivityPalette.textSecondary.color)
                    .lineLimit(1)
            }
        }
    }
}

private struct DynamicIslandProgressBar: View {
    @Environment(\.locale) private var locale
    let startDate: Date?
    let endDate: Date?
    let accent: Color

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { timeline in
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(PeckerLiveActivityPalette.hairline.color)

                    Capsule()
                        .fill(accent)
                        .frame(width: proxy.size.width * progress(at: timeline.date))
                }
            }
        }
        .frame(height: 4)
        .clipShape(Capsule())
        .accessibilityLabel(PeckerLiveActivityCopy.progressAccessibilityLabel(locale: locale))
        .accessibilityValue("\(Int(progress(at: .now) * 100))%")
    }

    private func progress(at date: Date) -> CGFloat {
        guard let startDate, let endDate, endDate > startDate else {
            return 0
        }

        let elapsed = date.timeIntervalSince(startDate)
        let total = endDate.timeIntervalSince(startDate)
        return min(max(elapsed / total, 0), 1)
    }
}

private struct RemainingMinutesText: View {
    let targetDate: Date
    let font: Font

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { timeline in
            Text(label(at: timeline.date))
                .font(font)
                .lineLimit(1)
        }
    }

    private func label(at date: Date) -> String {
        let remainingSeconds = max(targetDate.timeIntervalSince(date), 0)
        let minutes = max(Int(ceil(remainingSeconds / 60)), 1)

        if minutes >= 100 {
            return "\(minutes / 60)h"
        }

        return "\(minutes)m"
    }
}

private struct StatusDot: View {
    let color: Color
    var size: CGFloat = 7

    var body: some View {
        Circle()
            .fill(color)
            .frame(width: size, height: size)
            .shadow(color: color.opacity(0.45), radius: 3)
            .accessibilityHidden(true)
    }
}

private enum DynamicIslandStyle {
    static func statusColor(for state: PeckerActivityAttributes.ContentState) -> Color {
        statusColor(for: status(for: state))
    }

    static func statusColor(for status: PeckerLiveActivityStatus) -> Color {
        PeckerLiveActivityPalette.accentColor(for: status)
    }

    static func statusLabel(
        for state: PeckerActivityAttributes.ContentState,
        locale: Locale = .autoupdatingCurrent
    ) -> String {
        PeckerLiveActivityCopy.statusLabel(for: status(for: state), locale: locale)
    }

    static func compactTitle(for title: String) -> String? {
        let trimmed = title.trimmingCharacters(in: .whitespacesAndNewlines)

        guard !trimmed.isEmpty, trimmed.count <= 6, !trimmed.contains(" ") else {
            return nil
        }

        return trimmed
    }

    private static func status(for state: PeckerActivityAttributes.ContentState) -> PeckerLiveActivityStatus {
        switch state.primaryStatusRawValue {
        case "next":
            return .next
        case "pinned":
            return .pinned
        default:
            return .now
        }
    }
}

private enum DynamicIslandPreviewSamples {
    static var attributes: PeckerActivityAttributes {
        PeckerActivityAttributes(localDayIdentifier: "2026-06-24")
    }

    static let now = Date(timeIntervalSinceReferenceDate: 812_246_400)

    static let longTitle = state(
        primaryTitle: "Quarterly Strategy Review With Design Partners",
        primarySubtitle: "11:00–12:00",
        primaryStartDate: now.addingTimeInterval(-16 * 60),
        primaryEndDate: now.addingTimeInterval(44 * 60),
        primaryKindRawValue: "meeting",
        primarySourceIdentifier: "calendar",
        nextTitle: "Reply to launch notes",
        nextStartDate: now.addingTimeInterval(50 * 60),
        pinnedTitle: "SQ 833 · 14:35 · T3",
        pinnedSubtitle: "浦东机场",
        additionalActiveCount: 2
    )

    static let nextOnly = state(
        primaryTitle: "Lunch",
        primarySubtitle: nil,
        primaryStartDate: now.addingTimeInterval(23 * 60),
        primaryEndDate: nil,
        primaryKindRawValue: "upcoming",
        primarySourceIdentifier: "calendar",
        nextTitle: nil,
        nextStartDate: nil,
        pinnedTitle: nil,
        pinnedSubtitle: nil,
        additionalActiveCount: 0
    )

    private static func state(
        primaryTitle: String,
        primarySubtitle: String?,
        primaryStartDate: Date?,
        primaryEndDate: Date?,
        primaryKindRawValue: String,
        primarySourceIdentifier: String?,
        nextTitle: String?,
        nextStartDate: Date?,
        pinnedTitle: String?,
        pinnedSubtitle: String?,
        additionalActiveCount: Int
    ) -> PeckerActivityAttributes.ContentState {
        PeckerActivityAttributes.ContentState(
            primaryTitle: primaryTitle,
            primarySubtitle: primarySubtitle,
            primaryStartDate: primaryStartDate,
            primaryEndDate: primaryEndDate,
            primaryKindRawValue: primaryKindRawValue,
            primarySourceIdentifier: primarySourceIdentifier,
            nextTitle: nextTitle,
            nextStartDate: nextStartDate,
            pinnedTitle: pinnedTitle,
            pinnedSubtitle: pinnedSubtitle,
            additionalActiveCount: additionalActiveCount,
            generatedAt: now
        )
    }
}

#Preview("Dynamic Island expanded · long title", as: .dynamicIsland(.expanded), using: DynamicIslandPreviewSamples.attributes) {
    PeckerLiveActivityWidget()
} contentStates: {
    DynamicIslandPreviewSamples.longTitle
}

#Preview("Dynamic Island compact · long title", as: .dynamicIsland(.compact), using: DynamicIslandPreviewSamples.attributes) {
    PeckerLiveActivityWidget()
} contentStates: {
    DynamicIslandPreviewSamples.longTitle
}

#Preview("Dynamic Island minimal · long title", as: .dynamicIsland(.minimal), using: DynamicIslandPreviewSamples.attributes) {
    PeckerLiveActivityWidget()
} contentStates: {
    DynamicIslandPreviewSamples.longTitle
}

#Preview("Dynamic Island expanded · Next only", as: .dynamicIsland(.expanded), using: DynamicIslandPreviewSamples.attributes) {
    PeckerLiveActivityWidget()
} contentStates: {
    DynamicIslandPreviewSamples.nextOnly
}
