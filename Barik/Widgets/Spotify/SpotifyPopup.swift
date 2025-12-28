import SwiftUI

struct SpotifyPopup: View {
    @ObservedObject var configProvider: ConfigProvider
    @State private var selectedVariant: MenuBarPopupVariant = .horizontal

    var body: some View {
        MenuBarPopupVariantView(
            selectedVariant: selectedVariant,
            onVariantSelected: { variant in
                selectedVariant = variant
                ConfigManager.shared.updateConfigValue(
                    key: "widgets.default.spotify.popup.view-variant",
                    newValue: variant.rawValue
                )
            },
            vertical: { SpotifyVerticalPopup() },
            horizontal: { SpotifyHorizontalPopup() }
        )
        .onAppear(perform: loadVariant)
        .onReceive(configProvider.$config, perform: updateVariant)
    }

    private func loadVariant() {
        if let variantString = configProvider.config["popup"]?
            .dictionaryValue?["view-variant"]?.stringValue,
           let variant = MenuBarPopupVariant(rawValue: variantString) {
            selectedVariant = variant
        } else {
            selectedVariant = .box
        }
    }

    private func updateVariant(newConfig: ConfigData) {
        if let variantString = newConfig["popup"]?.dictionaryValue?["view-variant"]?.stringValue,
           let variant = MenuBarPopupVariant(rawValue: variantString) {
            selectedVariant = variant
        }
    }
}

// MARK: - Vertical Popup

private struct SpotifyVerticalPopup: View {
    @ObservedObject private var spotifyManager = SpotifyManager.shared

    var body: some View {
        if let track = spotifyManager.currentTrack {
            VStack(spacing: 15) {
                // Album artwork
                Group {
                    if let urlString = track.artworkURL,
                       let url = URL(string: urlString),
                       let nsImage = NSImage(contentsOf: url) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    } else {
                        RoundedRectangle(cornerRadius: 10, style: .continuous)
                            .fill(Color(red: 0.11, green: 0.73, blue: 0.33).opacity(0.3))
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.system(size: 50))
                                    .foregroundColor(.white.opacity(0.5))
                            )
                    }
                }
                .frame(width: 200, height: 200)
                .id(track.title + track.artist)
                .scaleEffect(track.state == .paused ? 0.9 : 1)
                .overlay(
                    track.state == .paused ?
                    Color.black.opacity(0.3)
                        .clipShape(RoundedRectangle(cornerRadius: 10, style: .continuous))
                    : nil
                )
                .animation(.smooth(duration: 0.5, extraBounce: 0.4), value: track.state == .paused)

                // Track info
                VStack(alignment: .center) {
                    Text(track.title)
                        .multilineTextAlignment(.center)
                        .font(.system(size: 15))
                        .fontWeight(.medium)
                    Text(track.artist)
                        .opacity(0.6)
                        .font(.system(size: 15))
                        .fontWeight(.light)
                }

                // Progress bar
                SpotifyProgressBar(track: track)

                // Playback controls
                SpotifyPlaybackControls()
            }
            .frame(width: 250)
            .padding(20)
        } else {
            SpotifyNotPlayingView()
                .frame(width: 250)
                .padding(20)
        }
    }
}

// MARK: - Horizontal Popup

private struct SpotifyHorizontalPopup: View {
    @ObservedObject private var spotifyManager = SpotifyManager.shared

    var body: some View {
        if let track = spotifyManager.currentTrack {
            HStack(spacing: 15) {
                // Album artwork
                Group {
                    if let urlString = track.artworkURL,
                       let url = URL(string: urlString),
                       let nsImage = NSImage(contentsOf: url) {
                        Image(nsImage: nsImage)
                            .resizable()
                            .scaledToFit()
                            .clipShape(RoundedRectangle(cornerRadius: 8, style: .continuous))
                    } else {
                        RoundedRectangle(cornerRadius: 8, style: .continuous)
                            .fill(Color(red: 0.11, green: 0.73, blue: 0.33).opacity(0.3))
                            .overlay(
                                Image(systemName: "music.note")
                                    .font(.system(size: 25))
                                    .foregroundColor(.white.opacity(0.5))
                            )
                    }
                }
                .frame(width: 60, height: 60)
                .scaleEffect(track.state == .paused ? 0.95 : 1)
                .animation(.smooth(duration: 0.3), value: track.state == .paused)

                VStack(alignment: .leading, spacing: 12) {
                    // Track info
                    VStack(alignment: .leading, spacing: 2) {
                        Text(track.title)
                            .font(.system(size: 13))
                            .fontWeight(.medium)
                            .lineLimit(1)
                        Text(track.artist)
                            .font(.system(size: 12))
                            .opacity(0.6)
                            .lineLimit(1)
                    }

                    // Progress bar
                    SpotifyProgressBar(track: track)

                    // Playback controls
                    SpotifyPlaybackControls()
                }
                .frame(width: 190)
            }
            .padding(15)
        } else {
            SpotifyNotPlayingView()
                .frame(width: 250)
                .padding(20)
        }
    }
}

// MARK: - Progress Bar

private struct SpotifyProgressBar: View {
    let track: SpotifyTrack
    @ObservedObject private var spotifyManager = SpotifyManager.shared

    var body: some View {
        VStack(spacing: 4) {
            GeometryReader { geometry in
                ZStack(alignment: .leading) {
                    Rectangle()
                        .fill(Color.gray.opacity(0.3))
                        .frame(height: 4)

                    Rectangle()
                        .fill(Color(red: 0.11, green: 0.73, blue: 0.33))
                        .frame(width: geometry.size.width * (track.position / max(track.duration, 1)), height: 4)
                }
                .clipShape(Capsule())
                .contentShape(Rectangle())
                .highPriorityGesture(
                    DragGesture(minimumDistance: 0)
                        .onEnded { value in
                            let clickedPosition = max(0, min(value.location.x / geometry.size.width, 1))
                            let newPosition = clickedPosition * track.duration
                            spotifyManager.seek(to: newPosition)
                        }
                )
            }
            .frame(height: 4)

            HStack {
                Text(formatTime(track.position))
                    .font(.system(size: 11))
                    .monospacedDigit()
                    .opacity(0.6)
                Spacer()
                Text(formatTime(track.duration))
                    .font(.system(size: 11))
                    .monospacedDigit()
                    .opacity(0.6)
            }
        }
    }

    private func formatTime(_ seconds: Double) -> String {
        let minutes = Int(seconds) / 60
        let secs = Int(seconds) % 60
        return String(format: "%d:%02d", minutes, secs)
    }
}

// MARK: - Playback Controls

private struct SpotifyPlaybackControls: View {
    @ObservedObject private var spotifyManager = SpotifyManager.shared

    var body: some View {
        HStack(spacing: 20) {
            Button(action: {
                spotifyManager.previousTrack()
            }) {
                Image(systemName: "backward.fill")
                    .font(.system(size: 18))
            }
            .buttonStyle(ScaleButtonStyle())

            Button(action: {
                spotifyManager.togglePlayPause()
            }) {
                Image(systemName: spotifyManager.currentTrack?.state == .playing ? "pause.fill" : "play.fill")
                    .font(.system(size: 22))
            }
            .buttonStyle(ScaleButtonStyle())

            Button(action: {
                spotifyManager.nextTrack()
            }) {
                Image(systemName: "forward.fill")
                    .font(.system(size: 18))
            }
            .buttonStyle(ScaleButtonStyle())
        }
    }
}

// MARK: - Not Playing View

private struct SpotifyNotPlayingView: View {
    @ObservedObject private var spotifyManager = SpotifyManager.shared

    var body: some View {
        VStack(spacing: 12) {
            Image(systemName: spotifyManager.isSpotifyRunning ? "pause.circle" : "music.note")
                .font(.system(size: 40))
                .foregroundColor(.gray.opacity(0.5))

            Text(spotifyManager.isSpotifyRunning ? "Not Playing" : "Spotify Not Running")
                .font(.system(size: 14))
                .opacity(0.6)

            if !spotifyManager.isSpotifyRunning {
                Text("Open Spotify to see playback controls")
                    .font(.system(size: 12))
                    .opacity(0.4)
                    .multilineTextAlignment(.center)
            }
        }
        .padding(30)
    }
}
