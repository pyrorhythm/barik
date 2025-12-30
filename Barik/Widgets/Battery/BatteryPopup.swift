import SwiftUI

struct BatteryPopup: View {
    @ObservedObject private var batteryManager = BatteryManager.shared

    private var statusText: String {
        if batteryManager.batteryLevel >= 100 && batteryManager.isPluggedIn {
            return "Fully Charged"
        } else if batteryManager.isCharging {
            return "Charging"
        } else if batteryManager.isPluggedIn {
            return "Plugged In"
        } else {
            return "On Battery"
        }
    }

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
            return "\(timeString) until full"
        } else {
            return "\(timeString) remaining"
        }
    }

    private var statusIcon: String {
        if batteryManager.batteryLevel >= 100 && batteryManager.isPluggedIn {
            return "checkmark.circle.fill"
        } else if batteryManager.isCharging {
            return "bolt.fill"
        } else if batteryManager.isPluggedIn {
            return "powerplug.fill"
        } else {
            return "battery.100"
        }
    }

    private var statusColor: Color {
        if batteryManager.isCharging || batteryManager.isPluggedIn {
            return .green
        } else if batteryManager.batteryLevel <= 10 {
            return .red
        } else if batteryManager.batteryLevel <= 20 {
            return .yellow
        } else {
            return .primary
        }
    }

    var body: some View {
        VStack(spacing: 12) {
            // Large percentage display
            Text("\(batteryManager.batteryLevel)%")
                .font(.system(size: 36, weight: .heavy, design: .rounded))
                .monospacedDigit()

            // Status row with icon
            HStack(spacing: 6) {
                Image(systemName: statusIcon)
                    .symbolRenderingMode(.hierarchical)
                    .foregroundStyle(statusColor)

                Text(statusText)
                    .font(.system(size: 13, weight: .bold, design: .rounded))
                    .foregroundStyle(.secondary)
            }

            // Time remaining (if available)
            if let timeText = timeRemainingText {
                Text(timeText)
                    .font(.system(size: 12, weight: .semibold, design: .rounded))
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.horizontal, 24)
        .padding(.vertical, 20)
    }
}

struct BatteryPopup_Previews: PreviewProvider {
    static var previews: some View {
        BatteryPopup()

            .previewLayout(.sizeThatFits)
    }
}
