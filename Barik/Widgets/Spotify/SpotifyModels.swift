import AppKit
import Foundation

// MARK: - Spotify Playback State

/// Represents the current Spotify playback state.
enum SpotifyPlaybackState: String {
    case playing, paused, stopped
}

// MARK: - Spotify Track Model

/// A model representing the currently playing Spotify track.
struct SpotifyTrack: Equatable, Identifiable {
    var id: String { trackId }
    let trackId: String
    let title: String
    let artist: String
    let album: String
    let artworkURL: String?
    let duration: Double  // Duration in seconds
    let position: Double  // Current position in seconds
    let state: SpotifyPlaybackState

    /// Creates an image from the artwork URL (cached).
    var artworkImage: NSImage? {
        guard let urlString = artworkURL,
              let url = URL(string: urlString),
              let data = try? Data(contentsOf: url) else {
            return nil
        }
        return NSImage(data: data)
    }
}
