import SwiftUI

struct MenuBarView: View {
    @ObservedObject var configManager = ConfigManager.shared
    @ObservedObject var displayManager = DisplayManager.shared

    private var theme: ColorScheme? {
        switch configManager.config.rootToml.theme {
        case "dark": return .dark
        case "light": return .light
        default: return nil
        }
    }

    private var backgroundStyle: BackgroundStyle {
        configManager.config.experimental.background.style
    }

    private var items: [TomlWidgetItem] {
        let allItems = configManager.config.rootToml.widgets.displayed
        let hiddenWidgets = displayManager.isBuiltinDisplay
            ? configManager.config.builtinDisplay.hiddenWidgets
            : []
        return allItems.filter { !hiddenWidgets.contains($0.id) }
    }

    private var spacerIndex: Int? {
        items.firstIndex(where: { $0.id == "spacer" })
    }

    private var leftItems: [TomlWidgetItem] {
        guard let idx = spacerIndex else { return items }
        return Array(items.prefix(idx))
    }

    private var rightItems: [TomlWidgetItem] {
        guard let idx = spacerIndex else { return [] }
        return Array(items.suffix(from: idx + 1))
    }

    var body: some View {
        HStack(spacing: 0) {
            switch backgroundStyle {
            case .splitPills:
                splitPillsLayout

            case .widgetPills, .none:
                standardLayout
            }

            if !items.contains(where: { $0.id == "system-banner" }) {
                SystemBannerWidget(withLeftPadding: true)
            }
        }
        .foregroundStyle(Color.foregroundOutside)
        .frame(maxWidth: .infinity)
        .frame(height: max(configManager.config.experimental.foreground.resolveHeight(), 1.0) + (configManager.config.experimental.foreground.verticalPadding * 2), alignment: .top)
        .padding(.horizontal, configManager.config.experimental.foreground.horizontalPadding)
        .background(.black.opacity(0.001))
        .preferredColorScheme(theme)
    }

    @ViewBuilder
    private var standardLayout: some View {
        HStack(spacing: configManager.config.experimental.foreground.spacing) {
            ForEach(0..<items.count, id: \.self) { index in
                buildView(for: items[index])
            }
        }
    }

    @ViewBuilder
    private var splitPillsLayout: some View {
        let pillHeight = configManager.config.experimental.foreground.resolveHeight()
        let verticalPadding = configManager.config.experimental.foreground.verticalPadding
        
        VStack {
            Spacer().frame(height: verticalPadding)
            HStack(spacing: configManager.config.experimental.foreground.spacing) {
                ForEach(0..<leftItems.count, id: \.self) { index in
                    buildView(for: leftItems[index])
                }
            }
            .frame(height: pillHeight)
            .padding(.horizontal, 12)
            .glassEffect(.clear.interactive())
            Spacer().frame(height: verticalPadding)
        }

        let minWidth = max(50, displayManager.notchSpacerWidth)
        Spacer().frame(minWidth: minWidth, maxWidth: .infinity)

        // Right pill
        VStack {
            Spacer().frame(height: verticalPadding)
            HStack(spacing: configManager.config.experimental.foreground.spacing) {
                ForEach(0..<rightItems.count, id: \.self) { index in
                    buildView(for: rightItems[index])
                }
            }
            .frame(height: pillHeight)
            .padding(.horizontal, 12)
            .glassEffect(.clear.interactive())
            Spacer().frame(height: verticalPadding)
        }
    }

    @ViewBuilder
    private func buildView(for item: TomlWidgetItem) -> some View {
        let config = ConfigProvider(
            config: configManager.resolvedWidgetConfig(for: item))

        switch item.id {
        case "default.system":
            SystemWidget().environmentObject(config)

        case "default.spaces":
            SpacesWidget().environmentObject(config)

        case "default.network":
            NetworkWidget().environmentObject(config)

        case "default.battery":
            BatteryWidget().environmentObject(config)

        case "default.time":
            TimeWidget(calendarManager: CalendarManager(configProvider: config))
                .environmentObject(config)

        case "default.nextmeeting":
            NextMeetingWidget(calendarManager: CalendarManager(configProvider: config))
                .environmentObject(config)

        case "default.nowplaying":
            NowPlayingWidget()
                .environmentObject(config)

        case "default.spotify":
            SpotifyWidget()
                .environmentObject(config)

        case "default.audiooutput":
            AudioOutputWidget()
                .environmentObject(config)

        case "default.caffeinate":
            CaffeinateWidget()
                .environmentObject(config)

        case "spacer":
            // On notched displays, ensure spacer is wide enough to keep content out of notch
            let minWidth = max(50, displayManager.notchSpacerWidth)
            Spacer().frame(minWidth: minWidth, maxWidth: .infinity)

        case "divider":
            Rectangle()
                .fill(Color.foregroundOutside.opacity(0.5))
                .frame(width: 3, height: 15)
                .clipShape(Capsule())
                .glow(color: .white.opacity(0.15), radius: 3)

        case "system-banner":
            SystemBannerWidget()

        default:
            Text("?\(item.id)?").foregroundColor(.red)
        }
    }
}
