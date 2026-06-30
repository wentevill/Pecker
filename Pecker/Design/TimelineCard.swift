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
    private let onDelete: () -> Void
    private let content: Content
    @State private var dragOffset: CGFloat = 0
    @State private var isOpen = false

    private let actionWidth: CGFloat = 82

    init(
        isEnabled: Bool,
        onDelete: @escaping () -> Void,
        @ViewBuilder content: () -> Content
    ) {
        self.isEnabled = isEnabled
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
                    Image(systemName: "trash.fill")
                        .font(.system(size: 17, weight: .semibold))
                        .foregroundStyle(.white)
                        .frame(width: actionWidth, height: 48)
                        .frame(maxHeight: .infinity)
                        .background(
                            RoundedRectangle(
                                cornerRadius: TimelineTheme.cardCornerRadius,
                                style: .continuous
                            )
                            .fill(Color.red)
                        )
                }
                .buttonStyle(.plain)
                .accessibilityLabel("\u{5220}\u{9664}")
            }

            content
                .offset(x: currentOffset)
                .contentShape(Rectangle())
                .gesture(
                    DragGesture(minimumDistance: 18)
                        .onChanged { value in
                            guard isEnabled,
                                  abs(value.translation.width)
                                    > abs(value.translation.height)
                            else {
                                return
                            }
                            let base = isOpen ? -actionWidth : 0
                            dragOffset = min(0, max(-actionWidth, base + value.translation.width))
                        }
                        .onEnded { value in
                            guard isEnabled else {
                                return
                            }
                            let projected = currentOffset + value.predictedEndTranslation.width * 0.08
                            withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
                                isOpen = projected < -actionWidth * 0.42
                                dragOffset = 0
                            }
                        }
                )
        }
        .clipped()
    }

    private var currentOffset: CGFloat {
        guard isEnabled else {
            return 0
        }
        return dragOffset != 0 ? dragOffset : (isOpen ? -actionWidth : 0)
    }

    private func close() {
        withAnimation(.spring(response: 0.24, dampingFraction: 0.86)) {
            isOpen = false
            dragOffset = 0
        }
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
