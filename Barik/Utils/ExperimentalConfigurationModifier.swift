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
                        .glassEffect(in: .rect(cornerRadius: cornerRadius, style: .continuous))
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
