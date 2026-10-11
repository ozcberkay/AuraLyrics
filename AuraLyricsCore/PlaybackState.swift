import Foundation

public struct PlaybackState: Equatable, CustomStringConvertible, Sendable {
    public let track: String
    public let artist: String
    public let album: String
    public let isPlaying: Bool
    public let position: TimeInterval
    public let duration: TimeInterval
    public let artworkUrl: String // URL string for the album art
    public let isSpotifyRunning: Bool // Whether the Spotify application is running
    public let timestamp: Date // Time when this state was captured, for sync interpolation
    public let trackID: String // Spotify track URI (spotify:track:...), "" when unknown

    public init(
        track: String,
        artist: String,
        album: String,
        isPlaying: Bool,
        position: TimeInterval,
        duration: TimeInterval,
        artworkUrl: String,
        isSpotifyRunning: Bool,
        timestamp: Date,
        trackID: String = ""
    ) {
        self.track = track
        self.artist = artist
        self.album = album
        self.isPlaying = isPlaying
        self.position = position
        self.duration = duration
        self.artworkUrl = artworkUrl
        self.isSpotifyRunning = isSpotifyRunning
        self.timestamp = timestamp
        self.trackID = trackID
    }

    public var description: String {
        if !isSpotifyRunning { return "[Spotify] Not Running" }
        return "[Spotify] \(isPlaying ? "▶️" : "⏸️") \(track) - \(artist) (\(String(format: "%.1f", position))s / \(String(format: "%.1f", duration))s)"
    }

    public static let empty = PlaybackState(
        track: "",
        artist: "",
        album: "",
        isPlaying: false,
        position: 0,
        duration: 0,
        artworkUrl: "",
        isSpotifyRunning: true,
        timestamp: Date()
    )

    public static let notRunning = PlaybackState(
        track: "",
        artist: "",
        album: "",
        isPlaying: false,
        position: 0,
        duration: 0,
        artworkUrl: "",
        isSpotifyRunning: false, // Explicitly false
        timestamp: Date()
    )
}

extension PlaybackState {
    /// Identifies one specific recording, not one song title.
    ///
    /// lrclib is queried with track, artist, album and duration, so a live take, a
    /// remaster and the studio version of the same song return different lyrics and
    /// different timings. Keying on title and artist alone made them share a single
    /// cache entry, and whichever was played first won for all of them.
    ///
    /// When Spotify gives a track id, the id is the key: the title, album or duration
    /// Spotify reports for the same recording can change, the id does not.
    public var lyricsCacheKey: String {
        if !trackID.isEmpty { return trackID }
        return "\(track)---\(artist)---\(album)---\(Int(duration))"
    }
}
