import SwiftUI

struct BatteryWidget: View {
    @EnvironmentObject var configProvider: ConfigProvider
    private var config: ConfigData { configProvider.config }
    private var showPercentage: Bool { config["show-percentage"]?.boolValue ?? false }
    private var warningLevel: Int { config["warning-level"]?.intValue ?? 20 }
    private var criticalLevel: Int { config["critical-level"]?.intValue ?? 10 }

    @ObservedObject private var batteryManager = BatteryManager.shared
    
    private var timeRemainingText: String? {
        guard let minutes = batteryManager.timeRemaining, minutes > 0 else {
            return nil
        }

        let hours = minutes / 60
        let mins = minutes % 60

        let timeString: String
        if hours > 0 && mins > 0 {
            timeString = "\(hours) hr \(mins) min"
        } else if hours > 0 {
            timeString = "\(hours) hr"
        } else {
            timeString = "\(mins) min"
        }

        if batteryManager.isCharging {
            return "To 100% in \(timeString)"
        } else {
            return "\(timeString) remaining"
        }
    }
    
    @State private var rect: CGRect = .zero

    var body: some View {
        HStack {
            VStack(alignment: .leading, spacing: -1) {
                HStack(spacing: 4) {
                    BatteryIconView(
                        level: batteryManager.batteryLevel,
                        isCharging: batteryManager.isCharging,
                        isPluggedIn: batteryManager.isPluggedIn,
                        warningLevel: warningLevel,
                        criticalLevel: criticalLevel
                    )
                    .frame(width: 26, height: 12)
                    
                    Text("\(batteryManager.batteryLevel)%")
                        .font(.system(size: 13, weight: .semibold, design: .rounded))
                }
                
                if let timeText = timeRemainingText {
                    Text(timeText)
                        .font(.system(size: 10, weight: .medium, design: .rounded))
                        .opacity(0.66)
                        .padding(.trailing, 2)
                }
            }
        }
        .background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear { rect = geometry.frame(in: .global) }
                    .onChange(of: geometry.frame(in: .global)) { _, newValue in
                        rect = newValue
                    }
            }
        )
        .transaction { tr in
            tr.animation = .smooth
        }
        .experimentalConfiguration(cornerRadius: 15)
        .frame(maxHeight: .infinity)
        .onTapGesture {
            MenuBarPopup.show(rect: rect, id: "battery") {
                BatteryPopup()
            }
        }
    }
}

// MARK: - Battery Icon View

private struct BatteryIconView: View {
    let level: Int
    let isCharging: Bool
    let isPluggedIn: Bool
    let warningLevel: Int
    let criticalLevel: Int

    // Battery dimensions (thicker, matching SF Symbol medium/regular weight)
    private let bodyCornerRadius: CGFloat = 3.5
    private let capWidth: CGFloat = 1.2
    private let capHeight: CGFloat = 7
    private let capCornerRadius: CGFloat = 2
    private let strokeWidth: CGFloat = 2
    private let fillInset: CGFloat = 2.0

    private var fillColor: Color {
        if level <= criticalLevel {
            return .red
        } else if level <= warningLevel {
            return .yellow
        } else if isCharging {
            return .green
        } else {
            return .primary
        }
    }

    var body: some View {
        GeometryReader { geometry in
            let totalWidth = geometry.size.width
            let totalHeight = geometry.size.height
            let bodyWidth = totalWidth - capWidth - 1
            let bodyHeight = totalHeight

            ZStack(alignment: .leading) {
                RoundedRectangle(cornerRadius: bodyCornerRadius)
                    .stroke(Color.active, lineWidth: strokeWidth)
                    .frame(width: bodyWidth, height: bodyHeight)

                RoundedRectangle(cornerRadius: capCornerRadius)
                    .fill(Color.active)
                    .frame(width: capWidth, height: capHeight)
                    .offset(x: bodyWidth + 1)

                RoundedRectangle(cornerRadius: bodyCornerRadius - fillInset / 2)
                    .fill(fillColor.opacity(0.9))
                    .frame(
                        width: max(0, (bodyWidth - fillInset * 2) * CGFloat(level) / 100),
                        height: bodyHeight - fillInset * 2
                    )
                    .offset(x: fillInset)
                    .animation(.easeInOut(duration: 0.3), value: level)

                if isCharging && level < 100 {
                    Image(systemName: "bolt.fill")
                        .font(.system(size: totalHeight+2, weight: .regular, design: .rounded))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(boltColor)
                        .offset(y: -0.5)
                        .frame(width: bodyWidth, height: bodyHeight, alignment: .center)
                }

                if isPluggedIn && !isCharging && level >= 100 {
                    Image(systemName: "powerplug.fill")
                        .font(.system(size: totalHeight * 0.6, weight: .semibold))
                        .symbolRenderingMode(.hierarchical)
                        .foregroundStyle(.black)
                        .frame(width: bodyWidth, height: bodyHeight, alignment: .center)
                }
            }.compositingGroup().padding([.trailing], 2)
        }
    }

    private var boltColor: Color {
        return .white
    }
}

// MARK: - Previews

struct BatteryWidget_Previews: PreviewProvider {
    static var previews: some View {
        HStack(spacing: 20) {
            // Full battery
            BatteryIconView(
                level: 100,
                isCharging: false,
                isPluggedIn: true,
                warningLevel: 20,
                criticalLevel: 10
            )
            .frame(width: 26, height: 12)

            // Charging
            BatteryIconView(
                level: 65,
                isCharging: true,
                isPluggedIn: true,
                warningLevel: 20,
                criticalLevel: 10
            )
            .frame(width: 26, height: 12)

            // Warning level
            BatteryIconView(
                level: 15,
                isCharging: false,
                isPluggedIn: false,
                warningLevel: 20,
                criticalLevel: 10
            )
            .frame(width: 26, height: 12)

            // Critical level
            BatteryIconView(
                level: 5,
                isCharging: false,
                isPluggedIn: false,
                warningLevel: 20,
                criticalLevel: 10
            )
            .frame(width: 26, height: 12)

            // Critical + charging
            BatteryIconView(
                level: 5,
                isCharging: true,
                isPluggedIn: true,
                warningLevel: 20,
                criticalLevel: 10
            )
            .frame(width: 26, height: 12)
        }
        .padding()
        
        .previewLayout(.sizeThatFits)
    }
}
