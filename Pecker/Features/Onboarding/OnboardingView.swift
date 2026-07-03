import SwiftUI

struct OnboardingView: View {
    @Bindable var model: OnboardingModel
    let onComplete: () -> Void
    private let localizer = AppLocalizer(language: .system)

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
                title: localizer.string("onboarding.welcome.title"),
                message: localizer.string("onboarding.welcome.message")
            ) {
                privacyBullet(
                    symbol: "lock.shield",
                    text: localizer.string("onboarding.welcome.bullet.device")
                )
                privacyBullet(
                    symbol: "hand.raised",
                    text: localizer.string("onboarding.welcome.bullet.permission")
                )
                privacyBullet(
                    symbol: "switch.2",
                    text: localizer.string("onboarding.welcome.bullet.sources")
                )
            }
        case .calendar:
            onboardingCard(
                symbol: "calendar",
                eyebrow: "CALENDAR",
                title: localizer.string("onboarding.calendar.title"),
                message: localizer.string("onboarding.calendar.message")
            ) {
                permissionNote(localizer.string("onboarding.calendar.note"))
            }
        case .reminders:
            onboardingCard(
                symbol: "checklist",
                eyebrow: "REMINDERS",
                title: localizer.string("onboarding.reminders.title"),
                message: localizer.string("onboarding.reminders.message")
            ) {
                permissionNote(localizer.string("onboarding.reminders.note"))
            }
        case .liveActivityIntroduction:
            onboardingCard(
                symbol: "livephoto",
                eyebrow: "LIVE ACTIVITY",
                title: localizer.string("onboarding.liveActivity.title"),
                message: localizer.string("onboarding.liveActivity.message")
            ) {
                permissionNote(localizer.string("onboarding.liveActivity.note"))
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
                    .accessibilityLabel(localizer.string("common.errorValue", errorMessage))
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
                Button(localizer.string("onboarding.skipSource")) {
                    let expectedStep = model.currentStep
                    _ = model.skipCurrentPermission(
                        expectedStep: expectedStep
                    )
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(TimelineTheme.textSecondary)
                .disabled(model.isBusy)
                .accessibilityHint(localizer.string("onboarding.skipSource.hint"))
            } else if model.currentStep == .liveActivityIntroduction {
                Button(localizer.string("onboarding.enableLater")) {
                    let expectedStep = model.currentStep
                    if model.completeWithoutLiveActivity(
                        expectedStep: expectedStep
                    ) {
                        onComplete()
                    }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(TimelineTheme.textSecondary)
                .accessibilityHint(localizer.string("onboarding.enableLater.hint"))
            }
        }
    }

    private var primaryButtonTitle: String {
        switch model.currentStep {
        case .welcome:
            localizer.string("onboarding.primary.welcome")
        case .calendar:
            localizer.string("onboarding.primary.calendar")
        case .reminders:
            localizer.string("onboarding.primary.reminders")
        case .liveActivityIntroduction:
            localizer.string("onboarding.primary.liveActivity")
        case .complete:
            localizer.string("onboarding.primary.complete")
        }
    }

    private var primaryButtonHint: String {
        switch model.currentStep {
        case .welcome:
            localizer.string("onboarding.hint.welcome")
        case .calendar:
            localizer.string("onboarding.hint.calendar")
        case .reminders:
            localizer.string("onboarding.hint.reminders")
        case .liveActivityIntroduction:
            localizer.string("onboarding.hint.liveActivity")
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
