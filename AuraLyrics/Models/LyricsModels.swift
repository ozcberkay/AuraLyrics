import Foundation

struct LyricsLine: Identifiable, Equatable, Codable {
    let id: UUID
    let startTime: TimeInterval
    let text: String
    let isSynced: Bool
}

struct LRCLibResponse: Codable {
    let id: Int?
    let name: String?
    let trackName: String?
    let artistName: String?
    let albumName: String?
    let duration: Double?
    let instrumental: Bool?
    let plainLyrics: String?
    let syncedLyrics: String?
}

enum LyricsState: Equatable {
    case idle
    case loading
    case loaded([LyricsLine])
    case notFound(track: String, artist: String)   // ERRH-01: show track info + "No lyrics available"
    case instrumental(track: String, artist: String)  // ERRH-02: music note icon + "Instrumental"
    case error(String)  // network/decode failures

    // Equatable conformance for associated value cases
    static func == (lhs: LyricsState, rhs: LyricsState) -> Bool {
        switch (lhs, rhs) {
        case (.idle, .idle), (.loading, .loading): return true
        case (.loaded(let a), .loaded(let b)): return a == b
        case (.notFound(let t1, let a1), .notFound(let t2, let a2)): return t1 == t2 && a1 == a2
        case (.instrumental(let t1, let a1), .instrumental(let t2, let a2)): return t1 == t2 && a1 == a2
        case (.error(let a), .error(let b)): return a == b
        default: return false
        }
    }
}
