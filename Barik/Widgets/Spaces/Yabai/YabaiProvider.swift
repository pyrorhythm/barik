import AppKit
import Foundation

class YabaiSpacesProvider: SpacesProvider, SwitchableSpacesProvider {
    typealias SpaceType = YabaiSpace
    let executablePath = ConfigManager.shared.config.yabai.path

    private func runYabaiCommand(arguments: [String]) -> Data? {
        let process = Process()
        process.executableURL = URL(fileURLWithPath: executablePath)
        process.arguments = arguments
        let pipe = Pipe()
        process.standardOutput = pipe
        do {
            try process.run()
        } catch {
            print("Yabai error: \(error)")
            return nil
        }
        let data = pipe.fileHandleForReading.readDataToEndOfFile()
        process.waitUntilExit()
        return data
    }

    private func fetchSpaces() -> [YabaiSpace]? {
        guard
            let data = runYabaiCommand(arguments: ["-m", "query", "--spaces"])
        else {
            return nil
        }
        let decoder = JSONDecoder()
        do {
            let spaces = try decoder.decode([YabaiSpace].self, from: data)
            return spaces
        } catch {
            print("Decode yabai spaces error: \(error)")
            return nil
        }
    }

    private func fetchWindows() -> [YabaiWindow]? {
        guard
            let data = runYabaiCommand(arguments: ["-m", "query", "--windows"])
        else {
            return nil
        }
        let decoder = JSONDecoder()
        do {
            let windows = try decoder.decode([YabaiWindow].self, from: data)
            return windows
        } catch {
            print("Decode yabai windows error: \(error)")
            return nil
        }
    }

    func getSpacesWithWindows() -> [YabaiSpace]? {
        // Run both queries in parallel for faster response
        var spaces: [YabaiSpace]?
        var windows: [YabaiWindow]?

        let group = DispatchGroup()

        group.enter()
        DispatchQueue.global(qos: .userInteractive).async {
            spaces = self.fetchSpaces()
            group.leave()
        }

        group.enter()
        DispatchQueue.global(qos: .userInteractive).async {
            windows = self.fetchWindows()
            group.leave()
        }

        group.wait()

        guard let spaces = spaces, let windows = windows else {
            return nil
        }
        // Exclude apps that don't show in the Dock (accessory/background apps like Hammerspoon, Raycast, etc.)
        // These apps keep windows alive even when "closed", so yabai can't detect their actual visibility
        let accessoryApps = Set(
            NSWorkspace.shared.runningApplications
                .filter { $0.activationPolicy != .regular }
                .compactMap { $0.localizedName }
        )

        let filteredWindows = windows.filter { window in
            // Basic filters
            guard window.opacity > 0 && !window.isHidden && !window.isSticky else { return false }
            guard !(window.isFloating && window.title.trimmingCharacters(in: .whitespaces).isEmpty) else { return false }

            // Exclude accessory/background apps entirely
            if accessoryApps.contains(window.appName ?? "") { return false }

            return true
        }
        var spaceDict = Dictionary(
            uniqueKeysWithValues: spaces.map { ($0.id, $0) })
        for window in filteredWindows {
            if var space = spaceDict[window.spaceId] {
                space.windows.append(window)
                spaceDict[window.spaceId] = space
            }
        }
        var resultSpaces = Array(spaceDict.values)
        for i in 0..<resultSpaces.count {
            resultSpaces[i].windows.sort { $0.stackIndex < $1.stackIndex }
        }
        return resultSpaces
    }

    func focusSpace(spaceId: String, needWindowFocus: Bool) {
        _ = runYabaiCommand(arguments: ["-m", "space", "--focus", spaceId])
        if !needWindowFocus { return }

        DispatchQueue.global(qos: .userInitiated).asyncAfter(
            deadline: .now() + 0.1
        ) {
            if let spaces = self.getSpacesWithWindows() {
                if let space = spaces.first(where: { $0.id == Int(spaceId) }) {
                    let hasFocused = space.windows.contains { $0.isFocused }
                    if !hasFocused, let firstWindow = space.windows.first {
                        _ = self.runYabaiCommand(arguments: [
                            "-m", "window", "--focus", String(firstWindow.id),
                        ])
                    }
                }
            }
        }
    }

    func focusWindow(windowId: String) {
        _ = runYabaiCommand(arguments: ["-m", "window", "--focus", windowId])
    }
}
