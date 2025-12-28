import AppKit
import Combine
import Foundation

// MARK: - Spotify Provider

/// Provides functionality to interact with Spotify via AppleScript.
final class SpotifyProvider {

    /// Checks if Spotify is currently running.
    static func isSpotifyRunning() -> Bool {
        let apps = NSWorkspace.shared.runningApplications
        return apps.contains { $0.bundleIdentifier == "com.spotify.client" }
    }

    /// Fetches the currently playing track from Spotify.
    static func fetchCurrentTrack() -> SpotifyTrack? {
        guard isSpotifyRunning() else { return nil }

        let script = """
        tell application "Spotify"
            if player state is stopped then
                return "stopped"
            end if

            set trackName to name of current track
            set trackArtist to artist of current track
            set trackAlbum to album of current track
            set trackId to id of current track
            set trackDuration to duration of current track
            set trackPosition to player position
            set playerState to player state as string
            set artworkUrl to artwork url of current track

            return trackName & "|||" & trackArtist & "|||" & trackAlbum & "|||" & trackId & "|||" & trackDuration & "|||" & trackPosition & "|||" & playerState & "|||" & artworkUrl
        end tell
        """

        guard let output = runAppleScript(script) else {
            return nil
        }

        if output == "stopped" {
            return nil
        }

        let components = output.components(separatedBy: "|||")
        guard components.count >= 8 else { return nil }

        let state: SpotifyPlaybackState = {
            switch components[6].lowercased() {
            case "playing": return .playing
            case "paused": return .paused
            default: return .stopped
            }
        }()
        
        
        return SpotifyTrack(
            trackId: components[3],
            title: components[0],
            artist: components[1],
            album: components[2],
            artworkURL: components[7],
            duration: (Double(components[4]) ?? 0.0) / 1000,
            position: Double(String(components[5].map { $0 == "," ? "." : $0 })) ?? 0.0,
            state: state
        )
    }

    /// Executes a playback command.
    static func executeCommand(_ command: String) {
        guard isSpotifyRunning() else { return }

        let script: String
        switch command {
        case "play":
            script = "tell application \"Spotify\" to play"
        case "pause":
            script = "tell application \"Spotify\" to pause"
        case "playpause":
            script = "tell application \"Spotify\" to playpause"
        case "next":
            script = "tell application \"Spotify\" to next track"
        case "previous":
            script = "tell application \"Spotify\" to previous track"
        default:
            return
        }

        runAppleScript(script)
    }

    /// Seeks to a specific position in seconds.
    static func seek(to position: Double) {
        guard isSpotifyRunning() else { return }

        let script = "tell application \"Spotify\" to set player position to \(position)"
        runAppleScript(script)
    }

    /// Runs an AppleScript and returns the output.
    @discardableResult
    private static func runAppleScript(_ script: String) -> String? {
        let process = Process()
        let pipe = Pipe()

        process.executableURL = URL(fileURLWithPath: "/usr/bin/osascript")
        process.arguments = ["-e", script]
        process.standardOutput = pipe
        process.standardError = Pipe()

        do {
            try process.run()
            process.waitUntilExit()

            let data = pipe.fileHandleForReading.readDataToEndOfFile()
            let output = String(data: data, encoding: .utf8)?.trimmingCharacters(in: .whitespacesAndNewlines)

            return output?.isEmpty == false ? output : nil
        } catch {
            return nil
        }
    }
}

// MARK: - Spotify Manager

/// Manager for Spotify playback state and control.
final class SpotifyManager: ObservableObject {
    static let shared = SpotifyManager()

    @Published private(set) var currentTrack: SpotifyTrack?
    @Published private(set) var isSpotifyRunning = false

    private var cancellable: AnyCancellable?
    private var sleepWakeObservers: [NSObjectProtocol] = []

    private init() {
        startMonitoring()
        observeSleepWake()
    }

    deinit {
        stopMonitoring()
        removeSleepWakeObservers()
    }

    private func observeSleepWake() {
        let sleepObserver = NotificationCenter.default.addObserver(
            forName: SleepWakeManager.willSleepNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.stopMonitoring()
        }

        let wakeObserver = NotificationCenter.default.addObserver(
            forName: SleepWakeManager.didWakeNotification,
            object: nil,
            queue: .main
        ) { [weak self] _ in
            self?.startMonitoring()
        }

        sleepWakeObservers.append(contentsOf: [sleepObserver, wakeObserver])
    }

    private func removeSleepWakeObservers() {
        sleepWakeObservers.forEach { NotificationCenter.default.removeObserver($0) }
        sleepWakeObservers.removeAll()
    }

    private func startMonitoring() {
        guard cancellable == nil else { return }
        cancellable = Timer.publish(every: 0.5, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updateCurrentTrack()
            }
    }

    private func stopMonitoring() {
        cancellable?.cancel()
        cancellable = nil
    }

    /// Updates the current track asynchronously.
    private func updateCurrentTrack() {
        DispatchQueue.global(qos: .background).async {
            let running = SpotifyProvider.isSpotifyRunning()
            let track = running ? SpotifyProvider.fetchCurrentTrack() : nil

            DispatchQueue.main.async { [weak self] in
                self?.isSpotifyRunning = running
                self?.currentTrack = track
            }
        }
    }

    /// Plays or resumes playback.
    func play() {
        SpotifyProvider.executeCommand("play")
    }

    /// Pauses playback.
    func pause() {
        SpotifyProvider.executeCommand("pause")
    }

    /// Toggles between play and pause.
    func togglePlayPause() {
        SpotifyProvider.executeCommand("playpause")
    }

    /// Skips to the previous track.
    func previousTrack() {
        SpotifyProvider.executeCommand("previous")
    }

    /// Skips to the next track.
    func nextTrack() {
        SpotifyProvider.executeCommand("next")
    }

    /// Seeks to a specific position in seconds.
    func seek(to position: Double) {
        SpotifyProvider.seek(to: position)
    }
}
