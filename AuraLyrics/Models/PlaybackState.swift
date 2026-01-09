import Foundation

struct PlaybackState: Equatable, CustomStringConvertible {
    let track: String
    let artist: String
    let album: String
    let isPlaying: Bool
    let position: TimeInterval
    let duration: TimeInterval
    let timestamp: Date // Time when this state was captured, for sync interpolation
    
    var description: String {
        return "[Spotify] \(isPlaying ? "▶️" : "⏸️") \(track) - \(artist) (\(String(format: "%.1f", position))s / \(String(format: "%.1f", duration))s)"
    }
    
    static let empty = PlaybackState(
        track: "",
        artist: "",
        album: "",
        isPlaying: false,
        position: 0,
        duration: 0,
        timestamp: Date()
    )
}
