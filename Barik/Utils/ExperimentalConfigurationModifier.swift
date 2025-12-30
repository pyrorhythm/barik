import SwiftUI

private struct ExperimentalConfigurationModifier: ViewModifier {
    @ObservedObject var configManager = ConfigManager.shared
    var foregroundHeight: CGFloat { configManager.config.experimental.foreground.resolveHeight() }
    var backgroundStyle: BackgroundStyle { configManager.config.experimental.background.style }

    let horizontalPadding: CGFloat
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        Group {
            switch backgroundStyle {
            case .widgetPills:
                VStack {
                    Spacer().frame(height: configManager.config.experimental.foreground.verticalPadding)
                    content
                        .frame(height: foregroundHeight)
                        .padding(.horizontal, 10)
                        .glassEffect(.clear.interactive())
                    Spacer().frame(height: configManager.config.experimental.foreground.verticalPadding)
                }

            case .splitPills, .none:
                content
            }
        }.scaleEffect(foregroundHeight < 25 ? 0.9 : 1, anchor: .leading)
    }
}

extension View {
    func experimentalConfiguration(
        horizontalPadding: CGFloat = 15,
        cornerRadius: CGFloat
    ) -> some View {
        self.modifier(ExperimentalConfigurationModifier(
            horizontalPadding: horizontalPadding,
            cornerRadius: cornerRadius
        ))
    }
}

extension View {
    func glow(color: Color = .red, radius: CGFloat = 20) -> some View {
        self
            .shadow(color: color, radius: radius / 3)
            .shadow(color: color, radius: radius / 3)
            .shadow(color: color, radius: radius / 3)
    }
}
