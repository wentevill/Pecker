import SwiftUI
import PeckerCore

enum ItemDetailAction {
    static func primaryButtonTitle(
        for item: TimelineItem,
        settings: TimelineSettings
    ) -> String {
        settings.manualPinnedSourceIdentifier == item.sourceIdentifier
            ? "\u{53d6}\u{6d88}\u{56fa}\u{5b9a}"
            : "\u{56fa}\u{5b9a}\u{884c}\u{7a0b}"
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

                if case let .trainTicket(ticket) = item.template {
                    TrainTicketTemplateView(
                        ticket: ticket,
                        fallbackDepartureTime: item.startDate,
                        fallbackArrivalTime: item.endDate
                    )
                }

                TimelineCard(accent: .neutral) {
                    VStack(alignment: .leading, spacing: 12) {
                        detailRow(title: "\u{6765}\u{6e90}", value: sourceText)
                        detailRow(title: "\u{7c7b}\u{578b}", value: kindText)
                        detailRow(title: "\u{65f6}\u{95f4}", value: timingText(now: now))
                        detailRow(title: "\u{5730}\u{70b9}", value: item.location.nilIfEmpty ?? "—")
                        detailRow(title: "\u{5907}\u{6ce8}", value: item.notes.nilIfEmpty ?? "—")
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

    static let navigationTitle = "\u{8be6}\u{60c5}"

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
            sourceText,
            kindText,
            item.isAllDay ? "\u{5168}\u{5929}" : "\u{5b9a}\u{65f6}",
            ItemDetailAction.primaryButtonTitle(for: item, settings: settings)
        ]
        .joined(separator: " · ")
    }

    private var sourceText: String {
        switch item.source {
        case .calendar: "\u{65e5}\u{5386}"
        case .reminder: "\u{63d0}\u{9192}\u{4e8b}\u{9879}"
        case .external: "Pecker"
        }
    }

    private var kindText: String {
        switch item.kind {
        case .meeting:
            "\u{4f1a}\u{8bae}"
        case .task:
            "\u{5f85}\u{529e}"
        case .flight:
            "\u{822a}\u{73ed}"
        case .train:
            "\u{706b}\u{8f66}"
        case .travel:
            "\u{884c}\u{7a0b}"
        case .interview:
            "\u{9762}\u{8bd5}"
        case .deadline:
            "\u{622a}\u{6b62}"
        case .unknown:
            "\u{672a}\u{5206}\u{7c7b}"
        }
    }

    private func timingText(now: Date) -> String {
        let formatter = Date.FormatStyle()
            .locale(Locale(identifier: "zh_CN"))
            .hour(.defaultDigits(amPM: .omitted))
            .minute()

        if item.isAllDay {
            return "\u{5168}\u{5929}"
        }

        guard let endDate = item.endDate else {
            return item.startDate.formatted(formatter)
        }

        let range = "\(item.startDate.formatted(formatter)) – \(endDate.formatted(formatter))"
        if item.startDate <= now, endDate > now {
            return "\(range) · \u{8fdb}\u{884c}\u{4e2d}"
        }
        if endDate <= now {
            return "\(range) · \u{5df2}\u{7ed3}\u{675f}"
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

private struct TrainTicketTemplateView: View {
    let ticket: TrainTicketTemplate
    let fallbackDepartureTime: Date
    let fallbackArrivalTime: Date?

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
                Text("\u{706b}\u{8f66}\u{7968}")
                    .font(.subheadline.weight(.bold))
            } icon: {
                Image(systemName: "train.side.front.car")
                    .foregroundStyle(TimelineTheme.next)
            }
            .labelStyle(.titleAndIcon)

            Spacer(minLength: 8)

            Text(ticket.trainNumber ?? "\u{5f85}\u{8bc6}\u{522b}\u{8f66}\u{6b21}")
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
                title: ticket.departureStation ?? "\u{51fa}\u{53d1}\u{7ad9}",
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
                title: ticket.arrivalStation ?? "\u{5230}\u{8fbe}\u{7ad9}",
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
            timeBlock(label: "\u{51fa}\u{53d1}", value: departureTimeText)
            Spacer(minLength: 12)
            timeBlock(label: "\u{5230}\u{8fbe}", value: arrivalTimeText)
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
            ticket.carriageNumber.map { "\($0)\u{8f66}\u{53a2}" },
            ticket.seatNumber.map { "\($0)\u{5ea7}" },
            ticket.checkInGate.map { "\u{68c0}\u{7968}\u{53e3} \($0)" },
            ticket.passengerName.map { "\u{4e58}\u{8f66}\u{4eba} \($0)" },
            ticket.ticketNumber.map { "\u{7968}\u{53f7} \($0)" }
        ]
        .compactMap(\.self)
    }

    private var departureTimeText: String {
        ticket.departureTimeText ?? Self.timeText(fallbackDepartureTime)
    }

    private var arrivalTimeText: String {
        if let arrivalTime = ticket.arrivalTimeText {
            return arrivalTime
        }
        guard let fallbackArrivalTime else {
            return "—"
        }
        return Self.timeText(fallbackArrivalTime)
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
            "\u{706b}\u{8f66}\u{7968}",
            ticket.trainNumber,
            ticket.departureStation,
            ticket.arrivalStation,
            "\u{51fa}\u{53d1} \(departureTimeText)",
            "\u{5230}\u{8fbe} \(arrivalTimeText)",
            ticket.carriageNumber.map { "\($0)\u{8f66}\u{53a2}" },
            ticket.seatNumber.map { "\($0)\u{5ea7}" },
            ticket.checkInGate.map { "\u{68c0}\u{7968}\u{53e3} \($0)" }
        ]
        .compactMap(\.self)
        .joined(separator: "，")
    }

    private static func timeText(_ date: Date) -> String {
        date.formatted(
            Date.FormatStyle()
                .hour(.defaultDigits(amPM: .omitted))
                .minute()
                .locale(Locale(identifier: "zh_CN"))
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

#Preview("Train ticket detail") {
    NavigationStack {
        ItemDetailView(
            item: TimelineItem(
                id: "train-ticket",
                sourceIdentifier: "train-ticket",
                title: "G123 \u{4e0a}\u{6d77}\u{8679}\u{6865} → \u{5317}\u{4eac}\u{5357}",
                startDate: TodayPreviewFixtures.makeSampleNow(),
                endDate: TodayPreviewFixtures.makeSampleNow().addingTimeInterval(4 * 3_600),
                isAllDay: false,
                source: .calendar,
                kind: .train,
                location: "\u{68c0}\u{7968}\u{53e3} B7",
                notes: "08\u{8f66} 03A",
                template: .trainTicket(.init(
                    trainNumber: "G123",
                    departureStation: "\u{4e0a}\u{6d77}\u{8679}\u{6865}",
                    arrivalStation: "\u{5317}\u{4eac}\u{5357}",
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
            onSettingsChanged: {}
        )
    }
}
#endif
