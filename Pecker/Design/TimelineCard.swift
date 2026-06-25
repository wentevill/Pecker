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

private struct TimelineReduceTransparencyOverrideKey: EnvironmentKey {
    static let defaultValue = false
}

extension EnvironmentValues {
    var timelineReduceTransparencyOverride: Bool {
        get { self[TimelineReduceTransparencyOverrideKey.self] }
        set { self[TimelineReduceTransparencyOverrideKey.self] = newValue }
    }
}
