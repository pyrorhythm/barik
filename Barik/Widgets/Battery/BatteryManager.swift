import Combine
import Foundation
import IOKit
import IOKit.ps

/// C-style callback invoked by IOKit when power source changes
private func powerSourceChangedCallback(context: UnsafeMutableRawPointer?) {
    guard let context = context else { return }
    let manager = Unmanaged<BatteryManager>.fromOpaque(context).takeUnretainedValue()
    DispatchQueue.main.async {
        manager.updateBatteryStatus()
    }
}

/// Event-driven battery status monitor using IOKit notifications.
/// Uses zero resources when idle by only updating on actual battery state changes.
class BatteryManager: ObservableObject {
    static let shared = BatteryManager()

    @Published var batteryLevel: Int = 0
    @Published var isCharging: Bool = false
    @Published var isPluggedIn: Bool = false
    @Published var timeRemaining: Int? = nil

    private var runLoopSource: CFRunLoopSource?

    private init() {
        let context = Unmanaged.passUnretained(self).toOpaque()
        if let loopSource = IOPSNotificationCreateRunLoopSource(
            powerSourceChangedCallback,
            context
        )?.takeRetainedValue() {
            self.runLoopSource = loopSource
            CFRunLoopAddSource(CFRunLoopGetCurrent(), loopSource, .defaultMode)
        }

        
        updateBatteryStatus()
    }

    deinit {
        if let runLoopSource = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetCurrent(), runLoopSource, .defaultMode)
        }
    }

    /// This method updates the battery level and charging state.
    func updateBatteryStatus() {
        guard let snapshot = IOPSCopyPowerSourcesInfo()?.takeRetainedValue(),
            let sources = IOPSCopyPowerSourcesList(snapshot)?
                .takeRetainedValue() as? [CFTypeRef]
        else {
            return
        }

        for source in sources {
            if let description = IOPSGetPowerSourceDescription(
                snapshot, source)?.takeUnretainedValue() as? [String: Any],
                let currentCapacity = description[
                    kIOPSCurrentCapacityKey as String] as? Int,
                let maxCapacity = description[kIOPSMaxCapacityKey as String]
                    as? Int,
                let charging = description[kIOPSIsChargingKey as String]
                    as? Bool,
                let powerSourceState = description[
                    kIOPSPowerSourceStateKey as String] as? String
            {
                let isAC = (powerSourceState == kIOPSACPowerValue)

                // Get time remaining (in minutes)
                let timeKey = charging ? kIOPSTimeToFullChargeKey : kIOPSTimeToEmptyKey
                let time = description[timeKey as String] as? Int
                // IOKit returns -1 if time is calculating/unknown
                let validTime = (time != nil && time! > 0) ? time : nil

                DispatchQueue.main.async {
                    self.batteryLevel = (currentCapacity * 100) / maxCapacity
                    self.isCharging = charging
                    self.isPluggedIn = isAC
                    self.timeRemaining = validTime
                }
            }
        }
    }
}
