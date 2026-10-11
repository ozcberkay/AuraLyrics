import Foundation

public struct LyricsLine: Identifiable, Equatable, Codable, Sendable {
    public let id: UUID
    public let startTime: TimeInterval
    public let text: String
    public let isSynced: Bool

    public init(id: UUID, startTime: TimeInterval, text: String, isSynced: Bool) {
        self.id = id
        self.startTime = startTime
        self.text = text
        self.isSynced = isSynced
    }
}

extension Array where Element == LyricsLine {
    /// The line being sung at `position`: the last one that has started.
    /// Blank entries are skipped: LRC files mark instrumental gaps with empty lines, and
    /// landing on one blanks out the middle of Aura mode. Holding the last sung line is
    /// what every other lyrics player does through a break.
    public func activeLine(at position: TimeInterval) -> LyricsLine? {
        last { $0.startTime <= position && !$0.text.isEmpty }
    }
}

struct LRCLibResponse: Codable, Sendable {
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

public enum LyricsState: Equatable, Sendable {
    case idle
    case loading
    case loaded([LyricsLine])
    case notFound(track: String, artist: String)   // show track info + "No lyrics available"
    case instrumental(track: String, artist: String)  // music note icon + "Instrumental"
    case error(String)  // network/decode failures

    // Equatable conformance for associated value cases
    public static func == (lhs: LyricsState, rhs: LyricsState) -> Bool {
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
