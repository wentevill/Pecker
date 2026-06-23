import SwiftUI

struct OnboardingView: View {
    @Bindable var model: OnboardingModel
    let onComplete: () -> Void

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [
                    Color(red: 0.025, green: 0.055, blue: 0.13),
                    Color(red: 0.055, green: 0.11, blue: 0.22),
                    Color(red: 0.08, green: 0.08, blue: 0.18)
                ],
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )
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
        .foregroundStyle(.white)
    }

    private var progress: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("\(model.currentStep.progress) / 4")
                .font(.subheadline.monospacedDigit().weight(.semibold))
                .foregroundStyle(.white.opacity(0.72))
                .accessibilityLabel(
                    "Onboarding step \(model.currentStep.progress) of 4"
                )

            ProgressView(
                value: Double(model.currentStep.progress),
                total: 4
            )
            .tint(Color(red: 0.42, green: 0.76, blue: 1))
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
                message: "把日历、提醒事项与正在进行的活动，整理成一条安静清晰的时间线。"
            ) {
                privacyBullet(
                    symbol: "lock.shield",
                    text: "你的日程留在设备与私人 App Group 中"
                )
                privacyBullet(
                    symbol: "hand.raised",
                    text: "仅在你点击时请求系统权限"
                )
                privacyBullet(
                    symbol: "switch.2",
                    text: "每个来源都可跳过，之后也能在设置中调整"
                )
            }
        case .calendar:
            onboardingCard(
                symbol: "calendar",
                eyebrow: "CALENDAR",
                title: "连接你的日历",
                message: "读取今天的事件，用于显示时间、地点与接下来的安排。拒绝或跳过不会阻止继续。"
            ) {
                permissionNote("权限请求只会在点击下方按钮后出现。")
            }
        case .reminders:
            onboardingCard(
                symbol: "checklist",
                eyebrow: "REMINDERS",
                title: "加入提醒事项",
                message: "把今天到期的任务放进时间线，与你的日历安排一起查看。"
            ) {
                permissionNote("即使未授权，你仍可以继续使用日历功能。")
            }
        case .liveActivityIntroduction:
            onboardingCard(
                symbol: "livephoto",
                eyebrow: "LIVE ACTIVITY",
                title: "开启 Live Activity",
                message: "在锁定屏幕与灵动岛快速查看当前安排。本步骤仅保存偏好，后续版本再接入系统活动。"
            ) {
                permissionNote("你可以稍后在设置中开启。")
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
                    .foregroundStyle(Color(red: 1, green: 0.72, blue: 0.68))
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .accessibilityLabel("错误：\(errorMessage)")
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
                            .tint(.black)
                            .accessibilityHidden(true)
                    }
                    Text(primaryButtonTitle)
                        .font(.headline)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 16)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.black)
            .background(
                Color(red: 0.62, green: 0.84, blue: 1),
                in: RoundedRectangle(cornerRadius: 18, style: .continuous)
            )
            .disabled(model.isBusy)
            .accessibilityLabel(primaryButtonTitle)
            .accessibilityHint(primaryButtonHint)

            if model.currentStep == .calendar
                || model.currentStep == .reminders {
                Button("跳过此来源") {
                    let expectedStep = model.currentStep
                    _ = model.skipCurrentPermission(
                        expectedStep: expectedStep
                    )
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.76))
                .disabled(model.isBusy)
                .accessibilityHint("不请求权限并继续下一步")
            } else if model.currentStep == .liveActivityIntroduction {
                Button("稍后开启") {
                    let expectedStep = model.currentStep
                    if model.completeWithoutLiveActivity(
                        expectedStep: expectedStep
                    ) {
                        onComplete()
                    }
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.white.opacity(0.76))
                .accessibilityHint("暂不开启 Live Activity 并完成设置")
            }
        }
    }

    private var primaryButtonTitle: String {
        switch model.currentStep {
        case .welcome:
            "开始设置"
        case .calendar:
            "允许访问日历"
        case .reminders:
            "允许访问提醒事项"
        case .liveActivityIntroduction:
            "开启 Live Activity"
        case .complete:
            "已完成"
        }
    }

    private var primaryButtonHint: String {
        switch model.currentStep {
        case .welcome:
            "继续到日历权限说明"
        case .calendar:
            "请求系统日历访问权限"
        case .reminders:
            "请求系统提醒事项访问权限"
        case .liveActivityIntroduction:
            "保存 Live Activity 偏好并完成设置"
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
                .foregroundStyle(Color(red: 0.52, green: 0.8, blue: 1))
                .accessibilityHidden(true)

            VStack(alignment: .leading, spacing: 10) {
                Text(eyebrow)
                    .font(.caption.weight(.bold))
                    .tracking(1.6)
                    .foregroundStyle(.white.opacity(0.58))
                Text(title)
                    .font(.largeTitle.bold())
                    .dynamicTypeSize(...DynamicTypeSize.accessibility3)
                Text(message)
                    .font(.body)
                    .foregroundStyle(.white.opacity(0.76))
                    .fixedSize(horizontal: false, vertical: true)
            }

            VStack(alignment: .leading, spacing: 14) {
                content()
            }
        }
        .padding(24)
        .background(.ultraThinMaterial, in: RoundedRectangle(
            cornerRadius: 28,
            style: .continuous
        ))
        .overlay {
            RoundedRectangle(cornerRadius: 28, style: .continuous)
                .stroke(.white.opacity(0.1), lineWidth: 1)
        }
    }

    private func privacyBullet(symbol: String, text: String) -> some View {
        Label(text, systemImage: symbol)
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.82))
            .fixedSize(horizontal: false, vertical: true)
    }

    private func permissionNote(_ text: String) -> some View {
        Label(text, systemImage: "info.circle")
            .font(.subheadline)
            .foregroundStyle(.white.opacity(0.72))
            .fixedSize(horizontal: false, vertical: true)
    }
}
