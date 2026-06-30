import ActivityKit
import SwiftUI
import WidgetKit

struct DynamicIslandLiveActivityView {
    private let state: PeckerActivityAttributes.ContentState

    init(context: ActivityViewContext<PeckerActivityAttributes>) {
        state = context.state
    }

    init(state: PeckerActivityAttributes.ContentState) {
        self.state = state
    }

    var body: DynamicIsland {
        DynamicIsland {
            DynamicIslandExpandedRegion(.leading) {
                ExpandedIdentity(state: state)
            }

            DynamicIslandExpandedRegion(.trailing) {
                ExpandedCountdown(state: state)
            }

            DynamicIslandExpandedRegion(.bottom) {
                ExpandedDetails(state: state)
            }
        } compactLeading: {
            CompactIdentity(state: state)
        } compactTrailing: {
            CompactCountdown(state: state)
        } minimal: {
            Image(systemName: state.symbolName)
                .font(.caption.weight(.bold))
                .foregroundStyle(typeColor)
        }
        .keylineTint(accent)
    }

    private var status: PeckerLiveActivityStatus {
        PeckerLiveActivityStyle.status(for: state.statusRawValue)
    }

    private var accent: Color {
        PeckerLiveActivityPalette.accentColor(for: status)
    }

    private var typeColor: Color {
        switch state.kindRawValue {
        case "flight":
            PeckerLiveActivityColorSpec.peckerOrange.color
        case "train":
            PeckerLiveActivityColorSpec.peckerBlue.color
        default:
            accent
        }
    }
}

private struct CompactIdentity: View {
    let state: PeckerActivityAttributes.ContentState

    var body: some View {
        HStack(spacing: 5) {
            Circle()
                .fill(accent)
                .frame(width: 7, height: 7)
            Image(systemName: state.symbolName)
                .font(.caption2.weight(.bold))
            Text(shortTitle)
                .font(.caption2.weight(.heavy))
                .lineLimit(1)
        }
        .foregroundStyle(typeColor)
    }

    private var shortTitle: String {
        if state.title.count <= 10 {
            return state.title
        }
        return String(state.title.prefix(8))
    }

    private var accent: Color {
        PeckerLiveActivityPalette.accentColor(
            for: PeckerLiveActivityStyle.status(for: state.statusRawValue)
        )
    }

    private var typeColor: Color {
        state.kindRawValue == "flight"
            ? PeckerLiveActivityColorSpec.peckerOrange.color
            : state.kindRawValue == "train"
                ? PeckerLiveActivityColorSpec.peckerBlue.color
                : accent
    }
}

private struct CompactCountdown: View {
    @Environment(\.locale) private var locale
    let state: PeckerActivityAttributes.ContentState

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { timeline in
            if state.hasEnded(at: timeline.date) {
                Image(systemName: "checkmark")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(PeckerLiveActivityPalette.textSecondary.color)
            } else if let target = state.countdownTargetDate(at: timeline.date) {
                RemainingMinutesText(targetDate: target)
            } else {
                Text(
                    PeckerLiveActivityCopy.statusLabel(
                        for: PeckerLiveActivityStyle.status(
                            for: state.statusRawValue
                        ),
                        locale: locale
                    )
                )
                .font(.caption2.weight(.heavy))
            }
        }
        .foregroundStyle(PeckerLiveActivityPalette.textPrimary.color)
    }
}

private struct ExpandedIdentity: View {
    @Environment(\.locale) private var locale
    let state: PeckerActivityAttributes.ContentState

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { timeline in
            HStack(alignment: .top, spacing: 9) {
                Image(systemName: state.symbolName)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(typeColor)
                    .frame(width: 34, height: 34)
                    .background(typeColor.opacity(0.16), in: Circle())

                VStack(alignment: .leading, spacing: 3) {
                    Text(
                        state.hasEnded(at: timeline.date)
                            ? PeckerLiveActivityCopy.endedLabel(locale: locale)
                            : PeckerLiveActivityCopy.statusLabel(
                                for: status,
                                locale: locale
                            )
                    )
                    .font(.caption2.weight(.heavy))
                    .foregroundStyle(
                        state.hasEnded(at: timeline.date) ? .gray : accent
                    )

                    Text(state.title)
                        .font(.subheadline.weight(.bold))
                        .foregroundStyle(
                            PeckerLiveActivityPalette.textPrimary.color
                        )
                        .lineLimit(2)
                        .minimumScaleFactor(0.78)

                    if let secondary = state.secondaryIdentity {
                        Text(secondary)
                            .font(.caption2)
                            .foregroundStyle(
                                PeckerLiveActivityPalette.textSecondary.color
                            )
                            .lineLimit(1)
                    }
                }
            }
        }
    }

    private var status: PeckerLiveActivityStatus {
        PeckerLiveActivityStyle.status(for: state.statusRawValue)
    }

    private var accent: Color {
        PeckerLiveActivityPalette.accentColor(for: status)
    }

    private var typeColor: Color {
        state.kindRawValue == "flight"
            ? PeckerLiveActivityColorSpec.peckerOrange.color
            : state.kindRawValue == "train"
                ? PeckerLiveActivityColorSpec.peckerBlue.color
                : accent
    }
}

private struct ExpandedCountdown: View {
    @Environment(\.locale) private var locale
    let state: PeckerActivityAttributes.ContentState

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { timeline in
            VStack(alignment: .trailing, spacing: 3) {
                if state.hasEnded(at: timeline.date) {
                    Text(PeckerLiveActivityCopy.endedLabel(locale: locale))
                        .font(.caption.weight(.bold))
                        .foregroundStyle(
                            PeckerLiveActivityPalette.textSecondary.color
                        )
                } else if let target = state.countdownTargetDate(at: timeline.date) {
                    Text(
                        target,
                        style: state.isPrimaryRunning(at: timeline.date)
                            ? .timer
                            : .relative
                    )
                    .font(.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(accent)
                    .lineLimit(1)

                    Text(
                        PeckerLiveActivityCopy.countdownHint(
                            isRunning: state.isPrimaryRunning(at: timeline.date),
                            locale: locale
                        )
                    )
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(
                        PeckerLiveActivityPalette.textSecondary.color
                    )
                }
            }
            .frame(maxWidth: .infinity, alignment: .trailing)
        }
    }

    private var accent: Color {
        PeckerLiveActivityPalette.accentColor(
            for: PeckerLiveActivityStyle.status(for: state.statusRawValue)
        )
    }
}

private struct ExpandedDetails: View {
    let state: PeckerActivityAttributes.ContentState

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { timeline in
            VStack(alignment: .leading, spacing: 7) {
                if let leading = state.leadingEndpoint,
                   let trailing = state.trailingEndpoint
                {
                    HStack(spacing: 8) {
                        Text(leading)
                            .lineLimit(1)
                        Image(systemName: "arrow.right")
                            .foregroundStyle(
                                PeckerLiveActivityColorSpec.peckerBlue.color
                            )
                        Text(trailing)
                            .lineLimit(1)
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(
                        PeckerLiveActivityPalette.textPrimary.color
                    )
                } else if let location = state.location {
                    Label(location, systemImage: "location.fill")
                        .font(.caption)
                        .foregroundStyle(
                            PeckerLiveActivityPalette.textSecondary.color
                        )
                        .lineLimit(1)
                } else if let detail = state.supportingDetail {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(
                            PeckerLiveActivityPalette.textSecondary.color
                        )
                        .lineLimit(1)
                }

                if !state.metadata.isEmpty {
                    Text(state.metadata.joined(separator: " · "))
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(
                            PeckerLiveActivityPalette.textSecondary.color
                        )
                        .lineLimit(1)
                }

                if state.isPrimaryRunning(at: timeline.date),
                   let progress = PeckerLiveActivityStyle.progress(
                       startDate: state.startDate,
                       endDate: state.endDate,
                       at: timeline.date
                   )
                {
                    IslandProgressBar(progress: progress, accent: accent)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
        }
    }

    private var accent: Color {
        PeckerLiveActivityPalette.accentColor(
            for: PeckerLiveActivityStyle.status(for: state.statusRawValue)
        )
    }
}

private struct RemainingMinutesText: View {
    let targetDate: Date

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { timeline in
            Text(label(at: timeline.date))
                .font(.caption2.weight(.bold).monospacedDigit())
                .lineLimit(1)
        }
    }

    private func label(at date: Date) -> String {
        let seconds = max(targetDate.timeIntervalSince(date), 0)
        let minutes = Int(ceil(seconds / 60))
        if minutes >= 100 {
            return "\(minutes / 60)h"
        }
        return "\(minutes)m"
    }
}

private struct IslandProgressBar: View {
    let progress: Double
    let accent: Color

    var body: some View {
        GeometryReader { proxy in
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(PeckerLiveActivityPalette.hairline.color)
                Capsule()
                    .fill(accent)
                    .frame(width: proxy.size.width * progress)
            }
        }
        .frame(height: 4)
        .clipShape(Capsule())
    }
}

private enum DynamicIslandPreviewSamples {
    static let now = Date(timeIntervalSinceReferenceDate: 812_246_400)
    static let flight = PeckerActivityAttributes.ContentState(
        itemIdentifier: "flight",
        title: "SQ 833",
        secondaryIdentity: "Singapore Airlines",
        kindRawValue: "flight",
        symbolName: "airplane",
        statusRawValue: "now",
        startDate: now.addingTimeInterval(-20 * 60),
        endDate: now.addingTimeInterval(86 * 60),
        leadingEndpoint: "PVG · \u{4e0a}\u{6d77}\u{6d66}\u{4e1c}",
        trailingEndpoint: "SIN · \u{65b0}\u{52a0}\u{5761}\u{6a1f}\u{5b9c}",
        location: nil,
        supportingDetail: nil,
        metadata: ["T3", "Gate B7", "12A \u{5ea7}", "\u{767b}\u{673a}\u{4e2d}"],
        generatedAt: now
    )
}

#Preview("Dynamic Island · Flight", as: .dynamicIsland(.expanded), using: PeckerActivityAttributes(localDayIdentifier: "2026-06-29")) {
    PeckerLiveActivityWidget()
} contentStates: {
    DynamicIslandPreviewSamples.flight
}
