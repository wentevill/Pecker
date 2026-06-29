import ActivityKit
import SwiftUI
import WidgetKit

struct LockScreenLiveActivityView: View {
    @Environment(\.locale) private var locale
    private let state: PeckerActivityAttributes.ContentState

    init(context: ActivityViewContext<PeckerActivityAttributes>) {
        state = context.state
    }

    init(state: PeckerActivityAttributes.ContentState) {
        self.state = state
    }

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { timeline in
            VStack(alignment: .leading, spacing: 14) {
                header(at: timeline.date)

                if state.hasEnded(at: timeline.date) {
                    endedContent
                } else if isTransport {
                    TransportActivityContent(state: state)
                } else {
                    GenericActivityContent(state: state)
                }

                if state.isPrimaryRunning(at: timeline.date),
                   let progress = PeckerLiveActivityStyle.progress(
                       startDate: state.startDate,
                       endDate: state.endDate,
                       at: timeline.date
                   )
                {
                    ActivityProgressBar(progress: progress, accent: accent)
                }
            }
            .padding(.vertical, 16)
            .padding(.horizontal, 18)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(cornerRadius: 22, style: .continuous)
                    .fill(PeckerLiveActivityPalette.backgroundGradient)
                    .overlay(alignment: .topTrailing) {
                        Circle()
                            .fill(typeColor.opacity(0.18))
                            .frame(width: 150, height: 150)
                            .blur(radius: 34)
                            .offset(x: 46, y: -70)
                    }
                    .overlay {
                        RoundedRectangle(cornerRadius: 22, style: .continuous)
                            .stroke(
                                PeckerLiveActivityPalette.hairline.color,
                                lineWidth: 1
                            )
                    }
            }
        }
    }

    private func header(at date: Date) -> some View {
        HStack(spacing: 10) {
            Circle()
                .fill(state.hasEnded(at: date) ? .gray : accent)
                .frame(width: 8, height: 8)
                .shadow(color: accent.opacity(0.45), radius: 3)

            Text(
                state.hasEnded(at: date)
                    ? PeckerLiveActivityCopy.endedLabel(locale: locale)
                    : PeckerLiveActivityCopy.statusLabel(
                        for: status,
                        locale: locale
                    )
            )
            .font(.caption2.weight(.heavy))
            .foregroundStyle(state.hasEnded(at: date) ? .gray : accent)

            Spacer(minLength: 8)

            if !state.hasEnded(at: date),
               let target = state.countdownTargetDate(at: date)
            {
                Text(
                    target,
                    style: state.isPrimaryRunning(at: date)
                        ? .timer
                        : .relative
                )
                .font(.headline.weight(.bold).monospacedDigit())
                .foregroundStyle(accent)
                .lineLimit(1)
            }
        }
    }

    private var endedContent: some View {
        HStack(spacing: 12) {
            TypeIcon(
                systemName: state.symbolName,
                color: PeckerLiveActivityPalette.textSecondary.color
            )
            VStack(alignment: .leading, spacing: 4) {
                Text(state.title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(PeckerLiveActivityPalette.textPrimary.color)
                    .lineLimit(1)
                Text(PeckerLiveActivityCopy.endedLabel(locale: locale))
                    .font(.caption)
                    .foregroundStyle(
                        PeckerLiveActivityPalette.textSecondary.color
                    )
            }
        }
    }

    private var isTransport: Bool {
        (state.kindRawValue == "train" || state.kindRawValue == "flight")
            && (state.leadingEndpoint != nil || state.trailingEndpoint != nil)
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

private struct TransportActivityContent: View {
    let state: PeckerActivityAttributes.ContentState

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(spacing: 11) {
                TypeIcon(
                    systemName: state.symbolName,
                    color: typeColor
                )
                VStack(alignment: .leading, spacing: 3) {
                    Text(state.title)
                        .font(.title3.weight(.black).monospacedDigit())
                        .foregroundStyle(
                            PeckerLiveActivityPalette.textPrimary.color
                        )
                        .lineLimit(1)

                    if let secondary = state.secondaryIdentity {
                        Text(secondary)
                            .font(.caption)
                            .foregroundStyle(
                                PeckerLiveActivityPalette.textSecondary.color
                            )
                            .lineLimit(1)
                    }
                }
            }

            HStack(alignment: .center, spacing: 10) {
                EndpointBlock(
                    date: state.startDate,
                    title: state.leadingEndpoint,
                    alignment: .leading
                )

                Image(systemName: "arrow.right")
                    .font(.subheadline.weight(.bold))
                    .foregroundStyle(
                        PeckerLiveActivityColorSpec.peckerBlue.color
                    )
                    .frame(maxWidth: .infinity)

                EndpointBlock(
                    date: state.endDate,
                    title: state.trailingEndpoint,
                    alignment: .trailing
                )
            }

            if !state.metadata.isEmpty {
                HStack(spacing: 6) {
                    ForEach(state.metadata, id: \.self) { value in
                        Text(value)
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(
                                PeckerLiveActivityPalette.textPrimary.color
                            )
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                            .padding(.horizontal, 7)
                            .padding(.vertical, 5)
                            .background(typeColor.opacity(0.12), in: Capsule())
                            .overlay {
                                Capsule()
                                    .stroke(typeColor.opacity(0.3), lineWidth: 1)
                            }
                    }
                }
            }
        }
    }

    private var typeColor: Color {
        state.kindRawValue == "flight"
            ? PeckerLiveActivityColorSpec.peckerOrange.color
            : PeckerLiveActivityColorSpec.peckerBlue.color
    }
}

private struct GenericActivityContent: View {
    let state: PeckerActivityAttributes.ContentState

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            TypeIcon(
                systemName: state.symbolName,
                color: PeckerLiveActivityColorSpec.peckerBlue.color
            )

            VStack(alignment: .leading, spacing: 5) {
                Text(state.title)
                    .font(.headline.weight(.bold))
                    .foregroundStyle(PeckerLiveActivityPalette.textPrimary.color)
                    .lineLimit(2)
                    .minimumScaleFactor(0.82)

                TimeRangeText(state: state)

                if let location = state.location {
                    Label(location, systemImage: "location.fill")
                        .font(.caption)
                        .foregroundStyle(
                            PeckerLiveActivityPalette.textSecondary.color
                        )
                        .lineLimit(1)
                }

                if let detail = state.supportingDetail,
                   detail != state.location
                {
                    Text(detail)
                        .font(.caption)
                        .foregroundStyle(
                            PeckerLiveActivityPalette.textSecondary.color
                        )
                        .lineLimit(1)
                }
            }
        }
    }
}

private struct EndpointBlock: View {
    let date: Date?
    let title: String?
    let alignment: HorizontalAlignment

    var body: some View {
        VStack(alignment: alignment, spacing: 3) {
            if let date {
                Text(date, style: .time)
                    .font(.title3.weight(.bold).monospacedDigit())
                    .foregroundStyle(PeckerLiveActivityPalette.textPrimary.color)
            }
            if let title {
                Text(title)
                    .font(.caption2)
                    .foregroundStyle(
                        PeckerLiveActivityPalette.textSecondary.color
                    )
                    .lineLimit(1)
                    .minimumScaleFactor(0.75)
            }
        }
        .frame(maxWidth: .infinity, alignment: alignment == .leading ? .leading : .trailing)
    }
}

private struct TimeRangeText: View {
    let state: PeckerActivityAttributes.ContentState

    var body: some View {
        if let start = state.startDate, let end = state.endDate {
            Text("\(start.formatted(date: .omitted, time: .shortened))–\(end.formatted(date: .omitted, time: .shortened))")
                .font(.caption.monospacedDigit())
                .foregroundStyle(PeckerLiveActivityPalette.textSecondary.color)
        } else if let start = state.startDate {
            Text(start, style: .time)
                .font(.caption.monospacedDigit())
                .foregroundStyle(PeckerLiveActivityPalette.textSecondary.color)
        }
    }
}

private struct TypeIcon: View {
    let systemName: String
    let color: Color

    var body: some View {
        Image(systemName: systemName)
            .font(.headline.weight(.bold))
            .foregroundStyle(color)
            .frame(width: 40, height: 40)
            .background(color.opacity(0.16), in: Circle())
    }
}

private struct ActivityProgressBar: View {
    @Environment(\.locale) private var locale
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
        .frame(height: 5)
        .clipShape(Capsule())
        .accessibilityLabel(
            PeckerLiveActivityCopy.progressAccessibilityLabel(locale: locale)
        )
        .accessibilityValue("\(Int(progress * 100))%")
    }
}

private enum LockScreenPreviewSamples {
    static let now = Date(timeIntervalSinceReferenceDate: 812_246_400)

    static let train = PeckerActivityAttributes.ContentState(
        itemIdentifier: "train",
        title: "C5770",
        secondaryIdentity: "成都东 → 重庆西",
        kindRawValue: "train",
        symbolName: "train.side.front.car",
        statusRawValue: "now",
        startDate: now.addingTimeInterval(-30 * 60),
        endDate: now.addingTimeInterval(48 * 60),
        leadingEndpoint: "成都东",
        trailingEndpoint: "重庆西",
        location: nil,
        supportingDetail: nil,
        metadata: ["02 车", "06D 座", "B3 检票口", "二等座"],
        generatedAt: now
    )

    static let flight = PeckerActivityAttributes.ContentState(
        itemIdentifier: "flight",
        title: "SQ 833",
        secondaryIdentity: "Singapore Airlines",
        kindRawValue: "flight",
        symbolName: "airplane",
        statusRawValue: "now",
        startDate: now.addingTimeInterval(-20 * 60),
        endDate: now.addingTimeInterval(86 * 60),
        leadingEndpoint: "PVG · 上海浦东",
        trailingEndpoint: "SIN · 新加坡樟宜",
        location: nil,
        supportingDetail: nil,
        metadata: ["T3", "Gate B7", "12A 座", "登机中"],
        generatedAt: now
    )
    static let meeting = state(
        id: "meeting",
        title: "Daily Standup",
        kind: "meeting",
        symbol: "person.2.fill",
        location: "会议室 A"
    )
    static let task = state(
        id: "task",
        title: "提交发布说明",
        kind: "task",
        symbol: "checklist",
        location: "产品发布清单"
    )
    static let travel = state(
        id: "travel",
        title: "酒店入住",
        kind: "travel",
        symbol: "suitcase.fill",
        location: "上海静安"
    )
    static let interview = state(
        id: "interview",
        title: "产品设计师终面",
        kind: "interview",
        symbol: "person.text.rectangle",
        location: "Zoom"
    )
    static let deadline = state(
        id: "deadline",
        title: "提交报销材料",
        kind: "deadline",
        symbol: "calendar.badge.exclamationmark",
        status: "next",
        startDate: now.addingTimeInterval(26 * 60),
        endDate: nil,
        location: "财务系统"
    )
    static let unknown = state(
        id: "unknown",
        title: "与 Alex 碰面",
        kind: "unknown",
        symbol: "clock.fill",
        location: "一楼咖啡厅"
    )

    private static func state(
        id: String,
        title: String,
        kind: String,
        symbol: String,
        status: String = "now",
        startDate: Date = now.addingTimeInterval(-20 * 60),
        endDate: Date? = now.addingTimeInterval(40 * 60),
        location: String?
    ) -> PeckerActivityAttributes.ContentState {
        PeckerActivityAttributes.ContentState(
            itemIdentifier: id,
            title: title,
            secondaryIdentity: nil,
            kindRawValue: kind,
            symbolName: symbol,
            statusRawValue: status,
            startDate: startDate,
            endDate: endDate,
            leadingEndpoint: nil,
            trailingEndpoint: nil,
            location: location,
            supportingDetail: "核心信息摘要",
            metadata: [],
            generatedAt: now
        )
    }
}

#Preview("Lock Screen · Train", as: .content, using: PeckerActivityAttributes(localDayIdentifier: "2026-06-29")) {
    PeckerLiveActivityWidget()
} contentStates: {
    LockScreenPreviewSamples.train
}

#Preview("Lock Screen · Flight", as: .content, using: PeckerActivityAttributes(localDayIdentifier: "2026-06-29")) {
    PeckerLiveActivityWidget()
} contentStates: {
    LockScreenPreviewSamples.flight
}

#Preview("Lock Screen · Meeting", as: .content, using: PeckerActivityAttributes(localDayIdentifier: "2026-06-29")) {
    PeckerLiveActivityWidget()
} contentStates: {
    LockScreenPreviewSamples.meeting
}

#Preview("Lock Screen · Task", as: .content, using: PeckerActivityAttributes(localDayIdentifier: "2026-06-29")) {
    PeckerLiveActivityWidget()
} contentStates: {
    LockScreenPreviewSamples.task
}

#Preview("Lock Screen · Travel", as: .content, using: PeckerActivityAttributes(localDayIdentifier: "2026-06-29")) {
    PeckerLiveActivityWidget()
} contentStates: {
    LockScreenPreviewSamples.travel
}

#Preview("Lock Screen · Interview", as: .content, using: PeckerActivityAttributes(localDayIdentifier: "2026-06-29")) {
    PeckerLiveActivityWidget()
} contentStates: {
    LockScreenPreviewSamples.interview
}

#Preview("Lock Screen · Deadline", as: .content, using: PeckerActivityAttributes(localDayIdentifier: "2026-06-29")) {
    PeckerLiveActivityWidget()
} contentStates: {
    LockScreenPreviewSamples.deadline
}

#Preview("Lock Screen · Unknown", as: .content, using: PeckerActivityAttributes(localDayIdentifier: "2026-06-29")) {
    PeckerLiveActivityWidget()
} contentStates: {
    LockScreenPreviewSamples.unknown
}
