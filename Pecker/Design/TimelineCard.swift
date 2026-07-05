import SwiftUI

struct TimelineCard<Content: View>: View {
    @Environment(\.accessibilityReduceTransparency) private var reduceTransparency
    @Environment(\.timelineReduceTransparencyOverride) private var reduceTransparencyOverride

    let accent: TimelineAccent
    let content: Content

    init(
        accent: TimelineAccent,
        @ViewBuilder content: () -> Content
    ) {
        self.accent = accent
        self.content = content()
    }

    var body: some View {
        let usesReducedTransparency = reduceTransparency || reduceTransparencyOverride

        content
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background {
                RoundedRectangle(
                    cornerRadius: TimelineTheme.cardCornerRadius,
                    style: .continuous
                )
                .fill(cardFill(usesReducedTransparency))
                .overlay {
                    RoundedRectangle(
                        cornerRadius: TimelineTheme.cardCornerRadius,
                        style: .continuous
                    )
                    .fill(
                        LinearGradient(
                            colors: [
                                Color.white.opacity(0.34),
                                TimelineTheme.color(for: accent).opacity(0.08),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blendMode(.screen)
                    .opacity(usesReducedTransparency ? 0.24 : 0.82)
                }
                .overlay {
                    RoundedRectangle(
                        cornerRadius: TimelineTheme.cardCornerRadius,
                        style: .continuous
                    )
                    .stroke(TimelineTheme.cardStroke, lineWidth: 1)
                }
                .shadow(color: TimelineTheme.cardShadow, radius: 26, x: 0, y: 16)
            }
    }

    private func cardFill(_ usesReducedTransparency: Bool) -> some ShapeStyle {
        if usesReducedTransparency {
            return AnyShapeStyle(TimelineTheme.cardFallbackFill)
        } else {
            return AnyShapeStyle(TimelineTheme.cardWarmFill)
        }
    }
}

struct SwipeDeleteAction<Content: View>: View {
    private let isEnabled: Bool
    private let deleteLabel: String
    private let onTap: () -> Void
    private let onDelete: () -> Void
    private let content: Content
    @State private var swipeState = SwipeDeleteState(actionWidth: 82)

    private let actionWidth: CGFloat = 82

    init(
        isEnabled: Bool,
        deleteLabel: String = "Delete",
        onTap: @escaping () -> Void = {},
        onDelete: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.isEnabled = isEnabled
        self.deleteLabel = deleteLabel
        self.onTap = onTap
        self.onDelete = onDelete
        self.content = content()
    }

    var body: some View {
        ZStack(alignment: .trailing) {
            if isEnabled {
                Button(role: .destructive) {
                    close()
                    onDelete()
                } label: {
                    VStack(spacing: 5) {
                        Image(systemName: "trash.fill")
                            .font(.system(size: 16, weight: .semibold))
                        Text(deleteLabel)
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(.white)
                    .frame(width: actionWidth)
                    .frame(maxHeight: .infinity)
                    .background {
                        RoundedRectangle(
                            cornerRadius: TimelineTheme.cardCornerRadius,
                            style: .continuous
                        )
                        .fill(
                            LinearGradient(
                                colors: [
                                    Color.red.opacity(0.92),
                                    Color(red: 0.82, green: 0.08, blue: 0.08)
                                ],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            )
                        )
                    }
                    .overlay {
                        RoundedRectangle(
                            cornerRadius: TimelineTheme.cardCornerRadius,
                            style: .continuous
                        )
                        .stroke(Color.white.opacity(0.18), lineWidth: 1)
                    }
                }
                .buttonStyle(.plain)
                .accessibilityLabel(deleteLabel)
                .accessibilityHidden(
                    !swipeState.deleteActionReceivesHitTesting
                )
                .allowsHitTesting(swipeState.deleteActionReceivesHitTesting)
                .zIndex(swipeState.deleteActionReceivesHitTesting ? 1 : -1)
            }

            content
                .background {
                    RoundedRectangle(
                        cornerRadius: TimelineTheme.cardCornerRadius,
                        style: .continuous
                    )
                    .fill(TimelineTheme.cardFallbackFill)
                }
                .offset(x: swipeState.currentOffset)
                .contentShape(Rectangle())
                .onTapGesture {
                    guard !swipeState.consumeTapSuppression() else {
                        return
                    }
                    if swipeState.isOpen {
                        close()
                    } else {
                        onTap()
                    }
                }
                .simultaneousGesture(
                    DragGesture(minimumDistance: 18)
                        .onChanged { value in
                            guard isEnabled,
                                  abs(value.translation.width)
                                    > abs(value.translation.height)
                            else {
                                return
                            }
                            swipeState.updateDrag(
                                translationWidth: value.translation.width,
                                isHorizontal: true
                            )
                        }
                        .onEnded { value in
                            guard isEnabled else {
                                return
                            }
                            withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                                swipeState.endDrag(
                                    predictedEndTranslationWidth: value.predictedEndTranslation.width
                                )
                            }
                        }
                )
                .zIndex(0)
        }
        .clipped()
        .onChange(of: isEnabled) { _, isEnabled in
            if !isEnabled {
                close()
            }
        }
    }

    private func close() {
        withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
            swipeState.close()
        }
    }
}

struct SwipeDeleteState: Equatable {
    let actionWidth: CGFloat
    var isOpen = false
    private var activeDragOffset: CGFloat?
    private var suppressNextTap = false

    init(actionWidth: CGFloat) {
        self.actionWidth = actionWidth
    }

    var currentOffset: CGFloat {
        activeDragOffset ?? (isOpen ? -actionWidth : 0)
    }

    var deleteActionReceivesHitTesting: Bool {
        isOpen || (activeDragOffset ?? 0) <= -actionWidth * 0.42
    }

    mutating func updateDrag(
        translationWidth: CGFloat,
        isHorizontal: Bool
    ) {
        guard isHorizontal else {
            return
        }
        let base: CGFloat = isOpen ? -actionWidth : 0
        activeDragOffset = min(0, max(-actionWidth, base + translationWidth))
        suppressNextTap = true
    }

    mutating func endDrag(predictedEndTranslationWidth: CGFloat) {
        let projected = currentOffset + predictedEndTranslationWidth * 0.08
        isOpen = projected < -actionWidth * 0.42
        activeDragOffset = nil
    }

    mutating func close() {
        isOpen = false
        activeDragOffset = nil
    }

    mutating func consumeTapSuppression() -> Bool {
        let shouldSuppress = suppressNextTap
        suppressNextTap = false
        return shouldSuppress
    }
}

private struct TimelineReduceTransparencyOverrideKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var timelineReduceTransparencyOverride: Bool {
        get { self[TimelineReduceTransparencyOverrideKey.self] }
        set { self[TimelineReduceTransparencyOverrideKey.self] = newValue }
    }
}
