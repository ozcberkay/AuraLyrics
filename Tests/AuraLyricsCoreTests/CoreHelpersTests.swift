import XCTest
import AuraLyricsCore

final class CoreHelpersTests: XCTestCase {

    private func state(album: String = "Studio", duration: TimeInterval = 200.4) -> PlaybackState {
        PlaybackState(track: "Song", artist: "Band", album: album, isPlaying: true,
                      position: 12, duration: duration, artworkUrl: "",
                      isSpotifyRunning: true, timestamp: Date())
    }

    private func line(_ start: TimeInterval, _ text: String) -> LyricsLine {
        LyricsLine(id: UUID(), startTime: start, text: text, isSynced: true)
    }

    // MARK: - Cache key

    func testCacheKeyDiffersByAlbum() {
        XCTAssertNotEqual(state(album: "Studio").lyricsCacheKey, state(album: "Live").lyricsCacheKey)
    }

    func testCacheKeyDiffersByDuration() {
        XCTAssertNotEqual(state(duration: 200).lyricsCacheKey, state(duration: 245).lyricsCacheKey)
    }

    func testCacheKeyIsStableForSameRecording() {
        // Position, play state and capture time change constantly; the key must not.
        let a = state()
        let b = PlaybackState(track: "Song", artist: "Band", album: "Studio", isPlaying: false,
                              position: 99, duration: 200.9, artworkUrl: "x",
                              isSpotifyRunning: true, timestamp: Date(timeIntervalSince1970: 0))
        XCTAssertEqual(a.lyricsCacheKey, b.lyricsCacheKey)
        XCTAssertEqual(a.lyricsCacheKey, "Song---Band---Studio---200")
    }

    // MARK: - App identity

    func testUserAgentIsContactable() {
        XCTAssertTrue(AppInfo.userAgent.hasPrefix("AuraLyrics/"))
        XCTAssertTrue(AppInfo.userAgent.contains(AppInfo.repositoryURL))
        XCTAssertTrue(AppInfo.repositoryURL.contains("github.com/ozcberkay/AuraLyrics"))
    }

    // MARK: - Active line

    func testActiveLineIsNilBeforeFirstLine() {
        let lines = [line(5, "first"), line(10, "second")]
        XCTAssertNil(lines.activeLine(at: 2))
    }

    func testActiveLinePicksLastStartedLine() {
        let lines = [line(5, "first"), line(10, "second"), line(15, "third")]
        XCTAssertEqual(lines.activeLine(at: 12)?.text, "second")
        XCTAssertEqual(lines.activeLine(at: 10)?.text, "second")
    }

    func testActiveLineSkipsBlankLines() {
        let lines = [line(5, "sung"), line(10, ""), line(20, "next")]
        XCTAssertEqual(lines.activeLine(at: 12)?.text, "sung", "a blank gap holds the last sung line")
    }
}
