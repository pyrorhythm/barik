import SwiftUI

struct BatteryWidget: View {
    @EnvironmentObject var configProvider: ConfigProvider
    var config: ConfigData { configProvider.config }
    var showPercentage: Bool { config["show-percentage"]?.boolValue ?? true }
    var warningLevel: Int { config["warning-level"]?.intValue ?? 20 }
    var criticalLevel: Int { config["critical-level"]?.intValue ?? 10 }

    @ObservedObject private var batteryManager = BatteryManager.shared
    private var level: Int { batteryManager.batteryLevel }
    private var isCharging: Bool { batteryManager.isCharging }
    private var isPluggedIn: Bool { batteryManager.isPluggedIn }

    @State private var rect: CGRect = CGRect()

    var body: some View {
        BatteryIconView(
            level: level,
            isCharging: isCharging,
            showPercentage: showPercentage,
            fillColor: batteryColor
        )
        .frame(width: 28, height: 14)
        .background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        rect = geometry.frame(in: .global)
                    }
                    .onChange(of: geometry.frame(in: .global)) { oldState, newState in
                        rect = newState
                    }
            }
        )
        .experimentalConfiguration(cornerRadius: 15)
        .frame(maxHeight: .infinity)
        .onTapGesture {
            MenuBarPopup.show(rect: rect, id: "battery") { BatteryPopup() }
        }
    }

    private var batteryColor: Color {
        if isCharging {
            return .green
        } else if level <= criticalLevel {
            return .red
        } else if level <= warningLevel {
            return .yellow
        } else {
            return .white
        }
    }
}

private struct BatteryIconView: View {
    @Environment(\.colorScheme) var colorScheme

    let level: Int
    let isCharging: Bool
    let showPercentage: Bool
    let fillColor: Color

    private var textColor: Color {
        colorScheme == .dark ? .white : .black
    }

    private var glowColor: Color {
        colorScheme == .dark ? .black : .white
    }

    var body: some View {
        GeometryReader { geometry in
            let width = geometry.size.width
            let height = geometry.size.height
            let fillMaxWidth = width * 0.77
            let currentFillWidth = fillMaxWidth * CGFloat(level) / 100.0
            
            ZStack {
                Image(systemName: "battery.0")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(Color(white: 0.4745).opacity(0.66))
                
                Image(systemName: "battery.100")
                    .resizable()
                    .scaledToFit()
                    .foregroundStyle(fillColor)
                    .mask(
                        HStack(spacing: 0) {
                            Rectangle()
                                .frame(width: currentFillWidth)
                            Spacer(minLength: 0)
                        }
                    )
                    .animation(.easeInOut(duration: 0.3), value: level)
                
                if !isCharging && level > 20 {
                    Image(systemName: "battery.0")
                        .resizable()
                        .scaledToFit()
                        .foregroundStyle(Color(white: 0.4745))

                }
                
                if showPercentage || (isCharging && level < 100) {
                    HStack(alignment: .center, spacing: 0) {
                        if showPercentage {
                            Text("\(level)")
                                .font(.system(size: height * 0.6, weight: .heavy, design: .rounded))
                                .minimumScaleFactor(0.5)
                        }
                        
                        if isCharging && level < 100 {
                            Image(systemName: "bolt.fill")
                                .font(.system(size: height * 0.45, weight: .heavy))
                        }
                    }
                    .foregroundStyle(textColor)
                    .glow(color: glowColor, radius: 1)
                    .offset(x: -width * 0.04)
                    .animation(.easeInOut(duration: 0.3), value: level)
                    .animation(.easeInOut(duration: 0.2), value: isCharging)
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
//            .glassEffect(.clear.tint(Color(white: 0.4745)))
        }
    }
}

struct BatteryWidget_Previews: PreviewProvider {
    static var previews: some View {
        VStack(spacing: 30) {
            // Dark background
            VStack(spacing: 10) {
                Text("Dark background").font(.caption).foregroundStyle(.white)
                HStack(spacing: 20) {
                    BatteryIconView(level: 87, isCharging: false, showPercentage: true, fillColor: .white)
                        .frame(width: 42, height: 14)
                    BatteryIconView(level: 62, isCharging: true, showPercentage: true, fillColor: .green)
                        .frame(width: 42, height: 14)
                    BatteryIconView(level: 15, isCharging: false, showPercentage: true, fillColor: .yellow)
                        .frame(width: 42, height: 14)
                    BatteryIconView(level: 5, isCharging: false, showPercentage: true, fillColor: .red)
                        .frame(width: 42, height: 14)
                }
            }
            .padding()
            .background(Color.black)

            // Light background
            VStack(spacing: 10) {
                Text("Light background").font(.caption)
                HStack(spacing: 20) {
                    BatteryIconView(level: 87, isCharging: false, showPercentage: true, fillColor: .white)
                        .frame(width: 42, height: 14)
                    BatteryIconView(level: 62, isCharging: true, showPercentage: true, fillColor: .green)
                        .frame(width: 42, height: 14)
                    BatteryIconView(level: 15, isCharging: false, showPercentage: true, fillColor: .yellow)
                        .frame(width: 42, height: 14)
                    BatteryIconView(level: 5, isCharging: false, showPercentage: true, fillColor: .red)
                        .frame(width: 42, height: 14)
                }
            }
            .padding()
            

            // Without percentage
            HStack(spacing: 20) {
                BatteryIconView(level: 60, isCharging: true, showPercentage: false, fillColor: .green)
                    .frame(width: 28, height: 14)
                BatteryIconView(level: 60, isCharging: false, showPercentage: false, fillColor: .white)
                    .frame(width: 28, height: 14)
            }
            .padding()
            
        }
    }
}
