import SwiftUI

// MARK: - Spotify Widget

struct SpotifyWidget: View {
    @EnvironmentObject var configProvider: ConfigProvider
    @ObservedObject var spotifyManager = SpotifyManager.shared

    @State private var widgetFrame: CGRect = .zero
    @State private var animatedWidth: CGFloat = 0

    var body: some View {
        ZStack(alignment: .trailing) {
            if let track = spotifyManager.currentTrack {
                // Hidden view for measuring width
                MeasurableSpotifyContent(track: track) { measuredWidth in
                    if animatedWidth == 0 {
                        animatedWidth = measuredWidth
                    } else if animatedWidth != measuredWidth {
                        withAnimation(.smooth) {
                            animatedWidth = measuredWidth
                        }
                    }
                }
                .hidden()
                VisibleSpotifyContent(track: track, width: animatedWidth)
                    
                    .onTapGesture {
                        MenuBarPopup.show(rect: widgetFrame, id: "spotify") {
                            SpotifyPopup(configProvider: configProvider)
                        }
                    }
                
            } else if spotifyManager.isSpotifyRunning {
                SpotifyIdleView()
                    
                    .onTapGesture {
                        MenuBarPopup.show(rect: widgetFrame, id: "spotify") {
                            SpotifyPopup(configProvider: configProvider)
                        }
                    }
                
            }
        }
        .experimentalConfiguration(cornerRadius: 15)
        .background(
            GeometryReader { geometry in
                Color.clear
                    .onAppear {
                        widgetFrame = geometry.frame(in: .global)
                    }
                    .onChange(of: geometry.frame(in: .global)) { _, newFrame in
                        widgetFrame = newFrame
                    }
            }
        )
        
    }
}

// MARK: - Spotify Idle View

struct SpotifyIdleView: View {
    @ObservedObject var configManager = ConfigManager.shared
    var foregroundHeight: CGFloat { configManager.config.experimental.foreground.resolveHeight() }

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "music.note")
                .font(.system(size: 12))
                .foregroundColor(.icon.opacity(0.6))

            Text("Spotify")
                .font(.system(size: 11))
                .foregroundColor(.foreground.opacity(0.6))
        }
        .frame(height: foregroundHeight < 45 ? 33 : 38)
        .padding(.vertical, 2)
    }
}

// MARK: - Spotify Content

struct SpotifyContent: View {
    let track: SpotifyTrack
    @ObservedObject var configManager = ConfigManager.shared
    var foregroundHeight: CGFloat { configManager.config.experimental.foreground.resolveHeight() }

    var body: some View {
        HStack() {
            SpotifyAlbumArtView(track: track).glow(color: .white.opacity(0.3), radius: 5)
            SpotifySongTextView(track: track)
        }
        
        .frame(height: foregroundHeight < 45 ? 33 : 38)
        .padding(.vertical, 2)
        
    }
}

// MARK: - Measurable Spotify Content

struct MeasurableSpotifyContent: View {
    let track: SpotifyTrack
    let onSizeChange: (CGFloat) -> Void

    var body: some View {
        SpotifyContent(track: track)
            .background(
                GeometryReader { geometry in
                    Color.clear
                        .onAppear {
                            onSizeChange(geometry.size.width)
                        }
                        .onChange(of: geometry.size.width) { _, newWidth in
                            onSizeChange(newWidth)
                        }
                }
            )
    }
}

// MARK: - Visible Spotify Content

struct VisibleSpotifyContent: View {
    let track: SpotifyTrack
    let width: CGFloat

    var body: some View {
        SpotifyContent(track: track)
            .frame(width: width, height: 38)
            .animation(.smooth(duration: 0.1), value: track)
            .transition(.blurReplace)
    }
}

// MARK: - Spotify Album Art View

struct SpotifyAlbumArtView: View {
    let track: SpotifyTrack

    var body: some View {
        SpotifyAlbumArtContent(
            artworkURL: track.artworkURL,
            title: track.title,
            artist: track.artist,
            isPaused: track.state == .paused
        )
    }
}

private struct SpotifyAlbumArtContent: View, Equatable {
    let artworkURL: String?
    let title: String
    let artist: String
    let isPaused: Bool

    static func == (lhs: SpotifyAlbumArtContent, rhs: SpotifyAlbumArtContent) -> Bool {
        lhs.title == rhs.title && lhs.artist == rhs.artist && lhs.isPaused == rhs.isPaused
    }

    var body: some View {
        ZStack {
            // Try to load artwork from URL
            if let urlString = artworkURL,
               let url = URL(string: urlString),
               let nsImage = NSImage(contentsOf: url) {
                Image(nsImage: nsImage)
                    .resizable()
                    .frame(width: 20, height: 20)
                    .clipShape(RoundedRectangle(cornerRadius: 4))
                    .scaleEffect(isPaused ? 0.9 : 1)
                    .brightness(isPaused ? -0.3 : 0)
            } else {
                // Spotify green placeholder
                RoundedRectangle(cornerRadius: 4)
                    .fill(Color(red: 0.11, green: 0.73, blue: 0.33).opacity(0.3))
                    .frame(width: 20, height: 20)
                    .overlay(
                        Image(systemName: "music.note")
                            .font(.system(size: 10))
                            .foregroundColor(.white.opacity(0.7))
                    )
            }

            if isPaused {
                Image(systemName: "pause.fill")
                    .foregroundColor(.icon)
                    .font(.system(size: 8))
                    .transition(.blurReplace)
            }
        }
        .animation(.smooth(duration: 0.1), value: isPaused)
        .transaction { transaction in
            transaction.animation = .interpolatingSpring
        }
    }
}

// MARK: - Spotify Song Text View

struct SpotifySongTextView: View {
    let track: SpotifyTrack
    @ObservedObject var configManager = ConfigManager.shared
    var foregroundHeight: CGFloat { configManager.config.experimental.foreground.resolveHeight() }

    var body: some View {
        VStack(alignment: .leading, spacing: -1) {
            ScrollingText(text: track.title, font: .system(size: 11, design: .rounded), fontWeight: .heavy)
                .padding(.trailing, 2)
            ScrollingText(text: track.artist, font: .system(size: 10, design: .rounded), fontWeight: .semibold, opacity: 0.8)
                .padding(.trailing, 2)
        }
        .transaction { transaction in
            transaction.animation = .interpolatingSpring
        }
    }
}

struct SpotifyContent_Preview: PreviewProvider {
    static var previews: some View {
        ZStack {
            SpotifyContent(track: SpotifyTrack(trackId: "123123", title: "123123", artist: "123123", album: "123123", artworkURL: nil, duration: 123123.213, position: 12312.123, state: .playing))
        }.frame(width: 200, height: 100)
            .environmentObject(ConfigProvider(config: [:]))
    }
}
