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
            .padding(12)
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
                                TimelineTheme.color(for: accent).opacity(0.18),
                                Color.clear
                            ],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .blendMode(.screen)
                    .opacity(usesReducedTransparency ? 0.2 : 0.7)
                }
                .overlay {
                    RoundedRectangle(
                        cornerRadius: TimelineTheme.cardCornerRadius,
                        style: .continuous
                    )
                    .stroke(TimelineTheme.cardStroke, lineWidth: 1)
                }
                .shadow(color: TimelineTheme.cardShadow, radius: 18, x: 0, y: 12)
            }
    }

    private func cardFill(_ usesReducedTransparency: Bool) -> some ShapeStyle {
        if usesReducedTransparency {
            return AnyShapeStyle(TimelineTheme.cardFallbackFill)
        } else {
            return AnyShapeStyle(.ultraThinMaterial)
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
