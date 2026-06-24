import ActivityKit
import SwiftUI
import WidgetKit

struct LockScreenLiveActivityView: View {
    private let state: PeckerActivityAttributes.ContentState

    init(context: ActivityViewContext<PeckerActivityAttributes>) {
        self.state = context.state
    }

    init(state: PeckerActivityAttributes.ContentState) {
        self.state = state
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack(alignment: .firstTextBaseline, spacing: 10) {
                VStack(alignment: .leading, spacing: 5) {
                    Text(primaryLabel)
                        .font(.caption2.weight(.heavy))
                        .foregroundStyle(primaryColor)
                        .textCase(.uppercase)

                    Text(state.primaryTitle)
                        .font(.headline.weight(.bold))
                        .foregroundStyle(.white)
                        .lineLimit(1)
                        .minimumScaleFactor(0.82)

                    if let subtitle = state.primarySubtitle, !subtitle.isEmpty {
                        Text(subtitle)
                            .font(.caption.monospacedDigit())
                            .foregroundStyle(.white.opacity(0.68))
                            .lineLimit(1)
                    }
                }

                Spacer(minLength: 8)

                if let endDate = state.primaryEndDate {
                    Text(endDate, style: .timer)
                        .font(.headline.weight(.bold).monospacedDigit())
                        .foregroundStyle(.white)
                        .lineLimit(1)
                }
            }

            if showsPrimaryProgress {
                ProgressBar(
                    startDate: state.primaryStartDate,
                    endDate: state.primaryEndDate,
                    accent: primaryColor
                )
            }

            if state.additionalActiveCount > 0 {
                Text("另有 \(state.additionalActiveCount) 项进行中")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)
            }

            VStack(alignment: .leading, spacing: 8) {
                if let nextTitle = state.nextTitle,
                   let nextStartDate = state.nextStartDate,
                   !isNextPrimary
                {
                    SupportingRow(
                        label: "NEXT",
                        title: nextTitle,
                        detail: nextStartDate.formatted(.relative(presentation: .numeric)),
                        color: Self.next
                    )
                }

                if let pinnedTitle = state.pinnedTitle, !isPinnedPrimary {
                    SupportingRow(
                        label: "PINNED",
                        title: pinnedTitle,
                        detail: state.pinnedSubtitle,
                        color: Self.pinned,
                        systemImage: "pin.fill"
                    )
                }
            }
            .padding(.top, 2)
        }
        .padding(.vertical, 16)
        .padding(.horizontal, 18)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background {
            RoundedRectangle(cornerRadius: 22, style: .continuous)
                .fill(Self.glass)
                .overlay(alignment: .topTrailing) {
                    Circle()
                        .fill(primaryColor.opacity(0.18))
                        .frame(width: 150, height: 150)
                        .blur(radius: 34)
                        .offset(x: 46, y: -70)
                }
                .overlay {
                    RoundedRectangle(cornerRadius: 22, style: .continuous)
                        .stroke(.white.opacity(0.1), lineWidth: 1)
                }
        }
    }

    private var showsPrimaryProgress: Bool {
        state.primaryStartDate != nil && state.primaryEndDate != nil
    }

    private var primaryLabel: String {
        if isPinnedPrimary {
            return "PINNED"
        }

        if isNextPrimary {
            return "NEXT"
        }

        return "NOW"
    }

    private var primaryColor: Color {
        if isPinnedPrimary {
            return Self.pinned
        }

        if isNextPrimary {
            return Self.next
        }

        return Self.now
    }

    private var isNextPrimary: Bool {
        state.primaryTitle == state.nextTitle
            || (state.primaryEndDate == nil && state.primaryStartDate != nil)
    }

    private var isPinnedPrimary: Bool {
        guard let pinnedTitle = state.pinnedTitle else {
            return false
        }

        return state.primaryTitle == pinnedTitle
            || state.primarySourceIdentifier?.localizedCaseInsensitiveContains("pinned") == true
            || state.primaryKindRawValue.localizedCaseInsensitiveContains("travel")
    }

    private static let now = Color(red: 0.52, green: 0.9, blue: 0.34)
    private static let next = Color(red: 0.34, green: 0.67, blue: 1.0)
    private static let pinned = Color(red: 1.0, green: 0.62, blue: 0.16)
    private static let glass = LinearGradient(
        colors: [
            Color(red: 0.018, green: 0.038, blue: 0.092).opacity(0.96),
            Color(red: 0.034, green: 0.065, blue: 0.145).opacity(0.92),
            Color.black.opacity(0.88)
        ],
        startPoint: .topLeading,
        endPoint: .bottomTrailing
    )
}

private struct ProgressBar: View {
    let startDate: Date?
    let endDate: Date?
    let accent: Color

    var body: some View {
        TimelineView(.periodic(from: .now, by: 30)) { timeline in
            GeometryReader { proxy in
                ZStack(alignment: .leading) {
                    Capsule()
                        .fill(.white.opacity(0.18))

                    Capsule()
                        .fill(accent)
                        .frame(width: proxy.size.width * progress(at: timeline.date))
                }
            }
        }
        .frame(height: 4)
        .clipShape(Capsule())
        .accessibilityLabel("进度")
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

private struct SupportingRow: View {
    let label: String
    let title: String
    let detail: String?
    let color: Color
    var systemImage: String?

    var body: some View {
        HStack(spacing: 7) {
            if let systemImage {
                Image(systemName: systemImage)
                    .font(.caption2.weight(.bold))
            }

            Text(label)
                .font(.caption2.weight(.heavy))

            Text(title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white)
                .lineLimit(1)

            Spacer(minLength: 6)

            if let detail, !detail.isEmpty {
                Text(detail)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.white.opacity(0.72))
                    .lineLimit(1)
            }
        }
        .foregroundStyle(color)
    }
}

private enum LockScreenLiveActivityPreviewSamples {
    static let now = Date(timeIntervalSinceReferenceDate: 812_246_400)

    static let nowNextPinned = state(
        primaryTitle: "Daily Standup",
        primarySubtitle: "09:30–10:00",
        primaryStartDate: now.addingTimeInterval(-18 * 60),
        primaryEndDate: now.addingTimeInterval(12 * 60),
        primaryKindRawValue: "meeting",
        nextTitle: "Product Review",
        nextStartDate: now.addingTimeInterval(18 * 60),
        pinnedTitle: "SQ 833 · 14:35 · T3",
        pinnedSubtitle: "浦东机场"
    )

    static let nowNext = state(
        primaryTitle: "Design Critique",
        primarySubtitle: "10:00–10:45",
        primaryStartDate: now.addingTimeInterval(-8 * 60),
        primaryEndDate: now.addingTimeInterval(37 * 60),
        primaryKindRawValue: "meeting",
        nextTitle: "Write launch notes",
        nextStartDate: now.addingTimeInterval(50 * 60)
    )

    static let nextOnly = state(
        primaryTitle: "Product Review",
        primarySubtitle: nil,
        primaryStartDate: now.addingTimeInterval(18 * 60),
        primaryEndDate: nil,
        primaryKindRawValue: "meeting",
        nextTitle: nil,
        nextStartDate: nil
    )

    static let pinnedOnly = state(
        primaryTitle: "SQ 833 · 14:35 · T3",
        primarySubtitle: "浦东机场",
        primaryStartDate: now.addingTimeInterval(3 * 60 * 60),
        primaryEndDate: now.addingTimeInterval(5 * 60 * 60),
        primaryKindRawValue: "travel",
        primarySourceIdentifier: "pinned-flight",
        pinnedTitle: "SQ 833 · 14:35 · T3",
        pinnedSubtitle: "浦东机场"
    )

    static let additionalActive = state(
        primaryTitle: "Daily Standup",
        primarySubtitle: "09:30–10:00",
        primaryStartDate: now.addingTimeInterval(-18 * 60),
        primaryEndDate: now.addingTimeInterval(12 * 60),
        primaryKindRawValue: "meeting",
        nextTitle: "Product Review",
        nextStartDate: now.addingTimeInterval(18 * 60),
        additionalActiveCount: 2
    )

    private static func state(
        primaryTitle: String,
        primarySubtitle: String? = nil,
        primaryStartDate: Date? = nil,
        primaryEndDate: Date? = nil,
        primaryKindRawValue: String,
        primarySourceIdentifier: String? = nil,
        nextTitle: String? = nil,
        nextStartDate: Date? = nil,
        pinnedTitle: String? = nil,
        pinnedSubtitle: String? = nil,
        additionalActiveCount: Int = 0
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

#Preview("Now + Next + Pinned") {
    LockScreenLiveActivityView(state: LockScreenLiveActivityPreviewSamples.nowNextPinned)
        .padding()
        .background(.black)
}

#Preview("Now + Next") {
    LockScreenLiveActivityView(state: LockScreenLiveActivityPreviewSamples.nowNext)
        .padding()
        .background(.black)
}

#Preview("Next only") {
    LockScreenLiveActivityView(state: LockScreenLiveActivityPreviewSamples.nextOnly)
        .padding()
        .background(.black)
}

#Preview("Pinned only") {
    LockScreenLiveActivityView(state: LockScreenLiveActivityPreviewSamples.pinnedOnly)
        .padding()
        .background(.black)
}

#Preview("Additional active") {
    LockScreenLiveActivityView(state: LockScreenLiveActivityPreviewSamples.additionalActive)
        .padding()
        .background(.black)
}
