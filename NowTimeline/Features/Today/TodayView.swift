import SwiftUI

struct TodayView: View {
    @Environment(\.calendar) private var calendar
    @Bindable var model: TodayViewModel
    @State private var path: [TodayRoute] = []

    var body: some View {
        NavigationStack(path: $path) {
            TimelineView(.periodic(from: .now, by: 60)) { context in
                TodayScreen(
                    content: content(now: context.date),
                    refreshAction: { await model.refresh() },
                    onOpenSettings: {
                        path.append(.settings)
                    },
                    onOpenCard: { card in
                        path.append(.detail(card))
                    },
                    onOpenSummary: {
                        path.append(.timeline)
                    },
                    onRetry: {
                        Task { await model.refresh() }
                    }
                )
            }
            .navigationDestination(for: TodayRoute.self) { route in
                TodayRoutePlaceholder(route: route)
            }
        }
    }

    private func content(now: Date) -> TodayScreenContent {
        TodayScreenContent.make(
            from: model.state,
            now: now,
            locale: Locale(identifier: "zh_CN"),
            calendar: calendar
        )
    }
}

private enum TodayRoute: Hashable {
    case settings
    case timeline
    case detail(TodayScreenContent.Card)
}

struct TodayScreen: View {
    let content: TodayScreenContent
    let refreshAction: () async -> Void
    let onOpenSettings: () -> Void
    let onOpenCard: (TodayScreenContent.Card) -> Void
    let onOpenSummary: () -> Void
    let onRetry: () -> Void

    var body: some View {
        ZStack {
            TimelineTheme.backgroundGradient
                .ignoresSafeArea()

            VStack(spacing: 0) {
                ScrollView {
                    VStack(alignment: .leading, spacing: 12) {
                        header
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
                            .fill(Color.white.opacity(0.09))
                    )
                    .overlay(
                        Circle()
                            .stroke(Color.white.opacity(0.12), lineWidth: 1)
                    )
            }
            .buttonStyle(.plain)
            .accessibilityLabel(content.header.settingsButtonLabel)
        }
        .padding(.top, 4)
    }

    @ViewBuilder
    private var bodyContent: some View {
        switch content.mode {
        case .loading:
            loadingState
        case .empty:
            emptyState
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
            title: TodayStateCopy.loadingTitle,
            message: "正在整理今天的日程。"
        ) {
            ProgressView()
                .tint(TimelineTheme.now)
        }
    }

    private var emptyState: some View {
        centeredState(
            icon: "calendar.badge.clock",
            title: TodayStateCopy.emptyTitle,
            message: "下拉即可刷新。"
        ) {
            Button(TodayStateCopy.staleRetry) {
                onRetry()
            }
            .buttonStyle(.plain)
            .font(.headline.weight(.semibold))
            .foregroundStyle(TimelineTheme.now)
        }
    }

    private var permissionState: some View {
        let permission = content.permission
        return TimelineCard(accent: .neutral) {
            VStack(alignment: .leading, spacing: 16) {
                Label {
                    Text(permission?.titleText ?? TodayStateCopy.permissionTitle)
                        .font(.headline.weight(.semibold))
                } icon: {
                    Image(systemName: "hand.raised.fill")
                        .foregroundStyle(TimelineTheme.neutral)
                }
                .labelStyle(.titleAndIcon)

                Text(permission?.bodyText ?? "允许访问后，Today 才能显示你的日程。")
                    .font(.body)
                    .foregroundStyle(TimelineTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button(permission?.buttonText ?? TodayStateCopy.permissionButton) {
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
                    Text(failure?.titleText ?? TodayStateCopy.failureTitle)
                        .font(.headline.weight(.semibold))
                } icon: {
                    Image(systemName: "exclamationmark.triangle.fill")
                        .foregroundStyle(Color.orange)
                }
                .labelStyle(.titleAndIcon)

                Text(failure?.bodyText ?? "请稍后再试。")
                    .font(.body)
                    .foregroundStyle(TimelineTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Button(failure?.retryText ?? TodayStateCopy.failureRetry) {
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

                Text(stale?.bannerText ?? TodayStateCopy.staleBanner)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(TimelineTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer(minLength: 8)

                Button(stale?.retryText ?? TodayStateCopy.staleRetry) {
                    onRetry()
                }
                .buttonStyle(.plain)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(TimelineTheme.next)
            }
        }
    }

    private var liveTimeline: some View {
        VStack(alignment: .leading, spacing: 10) {
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
        Button {
            onOpenCard(card)
        } label: {
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
        .buttonStyle(.plain)
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
                            Capsule().fill(TimelineTheme.color(for: card.accent).opacity(0.18))
                        )
                        .overlay(
                            Capsule().stroke(TimelineTheme.color(for: card.accent).opacity(0.25), lineWidth: 1)
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
                        .background(Circle().fill(Color.white.opacity(0.1)))
                        .overlay(Circle().stroke(Color.white.opacity(0.12), lineWidth: 1))

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
                        Capsule().fill(TimelineTheme.color(for: card.accent).opacity(0.18))
                    )
                    .overlay(
                        Capsule().stroke(TimelineTheme.color(for: card.accent).opacity(0.25), lineWidth: 1)
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
                .overlay(Circle().stroke(Color.white.opacity(0.16), lineWidth: 1))
                .shadow(color: TimelineTheme.lineColor(for: accent).opacity(0.28), radius: 8, x: 0, y: 0)

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
        .accessibilityLabel("进度 \(Int((progress * 100).rounded()))%")
    }

    private func segmentFill(for index: Int) -> Color {
        let threshold = Double(index + 1) / Double(segments)
        return threshold <= progress
            ? TimelineTheme.color(for: accent)
            : Color.white.opacity(0.18)
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
        case .settings:
            "设置"
        case .timeline:
            "完整时间线"
        case .detail(let card):
            card.titleText
        }
    }

    private var message: String {
        switch route {
        case .settings:
            "完整设置页留待下一步实现。"
        case .timeline:
            "完整时间线留待下一步实现。"
        case .detail(let card):
            "\(card.statusText) · \(card.timeText)"
        }
    }
}
