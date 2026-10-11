import XCTest
@testable import AuraLyricsCore

/// Measures how many tracks of a real listening corpus the fetcher finds on live LRCLIB.
/// Opt-in only: runs when LRCLIB_LIVE=1 and LRCLIB_CORPUS points at a corpus JSON file
/// (`{"tracks":[{"title":..., "artists":[...], "album":..., "duration_ms":...}]}`).
/// It reports coverage and never fails on a low number.
final class LiveCoverageTests: XCTestCase {

    private struct Corpus: Decodable {
        struct Track: Decodable {
            let title: String
            let artists: [String]
            let album: String
            let duration_ms: Int
        }
        let tracks: [Track]
    }

    func testLiveCoverage() async throws {
        let env = ProcessInfo.processInfo.environment
        try XCTSkipUnless(env["LRCLIB_LIVE"] == "1", "set LRCLIB_LIVE=1 to query live LRCLIB")
        guard let path = env["LRCLIB_CORPUS"], let data = FileManager.default.contents(atPath: path) else {
            throw XCTSkip("set LRCLIB_CORPUS to a readable corpus JSON file")
        }
        let corpus = try JSONDecoder().decode(Corpus.self, from: data)

        let fetcher = LyricsFetcher()
        var found = 0
        for track in corpus.tracks {
            // Spotify reports several artists as one comma-joined string.
            let artist = track.artists.joined(separator: ", ")
            let state = await fetcher.loadState(track: track.title, artist: artist, album: track.album,
                                                duration: Double(track.duration_ms) / 1000.0)
            switch state {
            case .loaded?, .instrumental?:
                found += 1
            default:
                print("MISS \(state.map { "\($0)" } ?? "nil") | \(track.title) | \(artist) | \(track.album)")
            }
        }
        print("coverage: \(found)/\(corpus.tracks.count)")
    }
}
