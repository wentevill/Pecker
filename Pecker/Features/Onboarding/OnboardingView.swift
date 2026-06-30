import SwiftUI

struct OnboardingView: View {
    @Bindable var model: OnboardingModel
    let onComplete: () -> Void

    var body: some View {
        ZStack {
            TimelineTheme.backgroundGradient
                .ignoresSafeArea()

            ScrollView {
                VStack(alignment: .leading, spacing: 28) {
                    progress
                    stepContent
                    Spacer(minLength: 20)
                    actions
                }
                .frame(maxWidth: 620, alignment: .leading)
                .padding(.horizontal, 24)
                .padding(.vertical, 28)
            }
        }
        .foregroundStyle(TimelineTheme.textPrimary)
    }

    private var progress: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(model.currentStep.progress) / 4")
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .foregroundStyle(TimelineTheme.textSecondary)
                .accessibilityLabel(
                    "Onboarding step \(model.currentStep.progress) of 4"
                )

            ProgressView(
                value: Double(model.currentStep.progress),
                total: 4
            )
            .tint(TimelineTheme.now)
            .accessibilityHidden(true)
        }
    }

    @ViewBuilder
    private var stepContent: some View {
        switch model.currentStep {
        case .welcome:
            onboardingCard(
                symbol: "sparkles",
                eyebrow: "NOW TIMELINE",
                title: "Your day, at a glance.",
                message: "\u{628a}\u{65e5}\u{5386}、\u{63d0}\u{9192}\u{4e8b}\u{9879}\u{4e0e}\u{6b63}\u{5728}\u{8fdb}\u{884c}\u{7684}\u{6d3b}\u{52a8}，\u{6574}\u{7406}\u{6210}\u{4e00}\u{6761}\u{5b89}\u{9759}\u{6e05}\u{6670}\u{7684}\u{65f6}\u{95f4}\u{7ebf}。"
            ) {
                privacyBullet(
                    symbol: "lock.shield",
                    text: "\u{4f60}\u{7684}\u{65e5}\u{7a0b}\u{7559}\u{5728}\u{8bbe}\u{5907}\u{4e0e}\u{79c1}\u{4eba} App Group \u{4e2d}"
                )
                privacyBullet(
                    symbol: "hand.raised",
                    text: "\u{4ec5}\u{5728}\u{4f60}\u{70b9}\u{51fb}\u{65f6}\u{8bf7}\u{6c42}\u{7cfb}\u{7edf}\u{6743}\u{9650}"
                )
                privacyBullet(
                    symbol: "switch.2",
                    text: "\u{6bcf}\u{4e2a}\u{6765}\u{6e90}\u{90fd}\u{53ef}\u{8df3}\u{8fc7}，\u{4e4b}\u{540e}\u{4e5f}\u{80fd}\u{5728}\u{8bbe}\u{7f6e}\u{4e2d}\u{8c03}\u{6574}"
                )
            }
        case .calendar:
            onboardingCard(
                symbol: "calendar",
                eyebrow: "CALENDAR",
                title: "\u{8fde}\u{63a5}\u{4f60}\u{7684}\u{65e5}\u{5386}",
                message: "\u{8bfb}\u{53d6}\u{4eca}\u{5929}\u{7684}\u{4e8b}\u{4ef6}，\u{7528}\u{4e8e}\u{663e}\u{793a}\u{65f6}\u{95f4}、\u{5730}\u{70b9}\u{4e0e}\u{63a5}\u{4e0b}\u{6765}\u{7684}\u{5b89}\u{6392}。\u{62d2}\u{7edd}\u{6216}\u{8df3}\u{8fc7}\u{4e0d}\u{4f1a}\u{963b}\u{6b62}\u{7ee7}\u{7eed}。"
            ) {
                permissionNote("\u{6743}\u{9650}\u{8bf7}\u{6c42}\u{53ea}\u{4f1a}\u{5728}\u{70b9}\u{51fb}\u{4e0b}\u{65b9}\u{6309}\u{94ae}\u{540e}\u{51fa}\u{73b0}。")
            }
        case .reminders:
            onboardingCard(
                symbol: "checklist",
                eyebrow: "REMINDERS",
                title: "\u{52a0}\u{5165}\u{63d0}\u{9192}\u{4e8b}\u{9879}",
                message: "\u{628a}\u{4eca}\u{5929}\u{5230}\u{671f}\u{7684}\u{4efb}\u{52a1}\u{653e}\u{8fdb}\u{65f6}\u{95f4}\u{7ebf}，\u{4e0e}\u{4f60}\u{7684}\u{65e5}\u{5386}\u{5b89}\u{6392}\u{4e00}\u{8d77}\u{67e5}\u{770b}。"
            ) {
                permissionNote("\u{5373}\u{4f7f}\u{672a}\u{6388}\u{6743}，\u{4f60}\u{4ecd}\u{53ef}\u{4ee5}\u{7ee7}\u{7eed}\u{4f7f}\u{7528}\u{65e5}\u{5386}\u{529f}\u{80fd}。")
            }
        case .liveActivityIntroduction:
            onboardingCard(
                symbol: "livephoto",
                eyebrow: "LIVE ACTIVITY",
                title: "\u{5f00}\u{542f} Live Activity",
                message: "\u{5728}\u{9501}\u{5b9a}\u{5c4f}\u{5e55}\u{4e0e}\u{7075}\u{52a8}\u{5c9b}\u{5feb}\u{901f}\u{67e5}\u{770b}\u{5f53}\u{524d}\u{5b89}\u{6392}。\u{5f00}\u{542f}\u{540e}，Pecker \u{4f1a}\u{5728}\u{4e0b}\u{6b21}\u{5237}\u{65b0}\u{65f6}\u{540c}\u{6b65}\u{5f53}\u{524d}\u{65f6}\u{95f4}\u{7ebf}。"
            ) {
                permissionNote("\u{4f60}\u{53ef}\u{4ee5}\u{7a0d}\u{540e}\u{5728}\u{8bbe}\u{7f6e}\u{4e2d}\u{5f00}\u{542f}。")
            }
        case .complete:
            EmptyView()
        }
    }

    private var actions: some View {
        VStack(spacing: 12) {
            if let errorMessage = model.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(TimelineTheme.now)
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel("\u{9519}\u{8bef}：\(errorMessage)")
            }

            Button {
                let expectedStep = model.currentStep
                Task {
                    let completed = await model.performPrimaryAction(
                        expectedStep: expectedStep
                    )
                    if completed && model.isComplete {
                        onComplete()
                    }
                }
            } label: {
                HStack(spacing: 10) {
                    if model.isBusy {
                        ProgressView()
                            .tint(.white)
                            .accessibilityHidden(true)
                    }
                    Text(primaryButtonTitle)
                        .font(.headline.weight(.semibold))
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.white)
            .background(
                TimelineTheme.now,
                in: RoundedRectangle(cornerRadius: 22, style: .continuous)
            )
            .shadow(color: TimelineTheme.now.opacity(0.24), radius: 18, x: 0, y: 10)
            .disabled(model.isBusy)
            .accessibilityLabel(primaryButtonTitle)
            .accessibilityHint(primaryButtonHint)

            if model.currentStep == .calendar
                || model.currentStep == .reminders {
                Button("\u{8df3}\u{8fc7}\u{6b64}\u{6765}\u{6e90}") {
                    let expectedStep = model.currentStep
                    _ = model.skipCurrentPermission(
                        expectedStep: expectedStep
                    )
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(TimelineTheme.textSecondary)
                .disabled(model.isBusy)
                .accessibilityHint("\u{4e0d}\u{8bf7}\u{6c42}\u{6743}\u{9650}\u{5e76}\u{7ee7}\u{7eed}\u{4e0b}\u{4e00}\u{6b65}")
            } else if model.currentStep == .liveActivityIntroduction {
                Button("\u{7a0d}\u{540e}\u{5f00}\u{542f}") {
                    let expectedStep = model.currentStep
                    if model.completeWithoutLiveActivity(
                        expectedStep: expectedStep
                    ) {
                        onComplete()
                    }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(TimelineTheme.textSecondary)
                .accessibilityHint("\u{6682}\u{4e0d}\u{5f00}\u{542f} Live Activity \u{5e76}\u{5b8c}\u{6210}\u{8bbe}\u{7f6e}")
            }
        }
    }

    private var primaryButtonTitle: String {
        switch model.currentStep {
        case .welcome:
            "\u{5f00}\u{59cb}\u{8bbe}\u{7f6e}"
        case .calendar:
            "\u{5141}\u{8bb8}\u{8bbf}\u{95ee}\u{65e5}\u{5386}"
        case .reminders:
            "\u{5141}\u{8bb8}\u{8bbf}\u{95ee}\u{63d0}\u{9192}\u{4e8b}\u{9879}"
        case .liveActivityIntroduction:
            "\u{5f00}\u{542f} Live Activity"
        case .complete:
            "\u{5df2}\u{5b8c}\u{6210}"
        }
    }

    private var primaryButtonHint: String {
        switch model.currentStep {
        case .welcome:
            "\u{7ee7}\u{7eed}\u{5230}\u{65e5}\u{5386}\u{6743}\u{9650}\u{8bf4}\u{660e}"
        case .calendar:
            "\u{8bf7}\u{6c42}\u{7cfb}\u{7edf}\u{65e5}\u{5386}\u{8bbf}\u{95ee}\u{6743}\u{9650}"
        case .reminders:
            "\u{8bf7}\u{6c42}\u{7cfb}\u{7edf}\u{63d0}\u{9192}\u{4e8b}\u{9879}\u{8bbf}\u{95ee}\u{6743}\u{9650}"
        case .liveActivityIntroduction:
            "\u{4fdd}\u{5b58} Live Activity \u{504f}\u{597d}\u{5e76}\u{5b8c}\u{6210}\u{8bbe}\u{7f6e}"
        case .complete:
            ""
        }
    }

    private func onboardingCard<Content: View>(
        symbol: String,
        eyebrow: String,
        title: String,
        message: String,
        @ViewBuilder content: () -> Content
    ) -> some View {
        VStack(alignment: .leading, spacing: 22) {
            Image(systemName: symbol)
                .font(.system(size: 42, weight: .medium))
                .foregroundStyle(TimelineTheme.now)
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 10) {
                Text(eyebrow)
                    .font(.caption.weight(.bold))
                    .tracking(1.6)
                    .foregroundStyle(TimelineTheme.textTertiary)
                Text(title)
                    .font(.system(size: 36, weight: .bold, design: .serif))
                    .dynamicTypeSize(...DynamicTypeSize.accessibility3)
                Text(message)
                    .font(.body)
                    .foregroundStyle(TimelineTheme.textSecondary)
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 14) {
                content()
            }
        }
        .padding(24)
        .background(TimelineTheme.cardWarmFill, in: RoundedRectangle(
            cornerRadius: 28,
            style: .continuous
        ))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(TimelineTheme.cardStroke, lineWidth: 1)
        }
        .shadow(color: TimelineTheme.cardShadow, radius: 26, x: 0, y: 16)
    }

    private func privacyBullet(symbol: String, text: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.subheadline)
            .foregroundStyle(TimelineTheme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }

    private func permissionNote(_ text: String) -> some View {
        Label(text, systemImage: "info.circle")
            .font(.subheadline)
            .foregroundStyle(TimelineTheme.textSecondary)
            .fixedSize(horizontal: false, vertical: true)
    }
}
