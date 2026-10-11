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

    func testCacheKeyIsTrackIDWhenPresent() {
        let withID = PlaybackState(track: "Song", artist: "Band", album: "Studio", isPlaying: true,
                                   position: 0, duration: 200, artworkUrl: "", isSpotifyRunning: true,
                                   timestamp: Date(), trackID: "spotify:track:abc")
        XCTAssertEqual(withID.lyricsCacheKey, "spotify:track:abc")
    }

    func testCacheKeyFallsBackToMetadataWithoutTrackID() {
        // The default trackID is "", so callers that never set it keep the metadata key.
        XCTAssertEqual(state().trackID, "")
        XCTAssertEqual(state().lyricsCacheKey, "Song---Band---Studio---200")
    }

    // MARK: - App identity

    func testUserAgentIsContactable() {
        XCTAssertTrue(AppInfo.userAgent.hasPrefix("AuraLyrics/"))
        XCTAssertTrue(AppInfo.userAgent.contains(AppInfo.repositoryURL))
        XCTAssertTrue(AppInfo.repositoryURL.contains("github.com/ozcberkay/AuraLyrics"))
    }

    func testVersionDescriptionFallsBackToDev() {
        XCTAssertEqual(AppInfo.versionDescription(infoDictionary: nil), "dev")
        XCTAssertEqual(AppInfo.versionDescription(infoDictionary: [:]), "dev")
        XCTAssertEqual(AppInfo.versionDescription(infoDictionary: ["CFBundleShortVersionString": ""]), "dev")
        XCTAssertEqual(AppInfo.shortVersion(infoDictionary: nil), "dev")
    }

    func testVersionDescriptionShortVersionOnly() {
        XCTAssertEqual(AppInfo.versionDescription(infoDictionary: ["CFBundleShortVersionString": "1.2.0"]), "1.2.0")
    }

    func testVersionDescriptionHidesBuildEqualToVersion() {
        let info: [String: Any] = ["CFBundleShortVersionString": "1.2.0", "CFBundleVersion": "1.2.0"]
        XCTAssertEqual(AppInfo.versionDescription(infoDictionary: info), "1.2.0")
    }

    func testVersionDescriptionShowsDifferentBuild() {
        let info: [String: Any] = ["CFBundleShortVersionString": "1.2.0", "CFBundleVersion": "142"]
        XCTAssertEqual(AppInfo.versionDescription(infoDictionary: info), "1.2.0 (142)")
    }

    func testVersionDescriptionCommitOnly() {
        let info: [String: Any] = ["CFBundleShortVersionString": "1.2.0", AppInfo.gitCommitKey: "abc1234"]
        XCTAssertEqual(AppInfo.versionDescription(infoDictionary: info), "1.2.0 (abc1234)")
    }

    func testVersionDescriptionBuildAndCommit() {
        let info: [String: Any] = [
            "CFBundleShortVersionString": "1.2.0", "CFBundleVersion": "142", AppInfo.gitCommitKey: "abc1234",
        ]
        XCTAssertEqual(AppInfo.versionDescription(infoDictionary: info), "1.2.0 (142, abc1234)")
    }

    func testVersionDescriptionIgnoresNonStringValues() {
        let info: [String: Any] = ["CFBundleShortVersionString": "1.2.0", "CFBundleVersion": 142, AppInfo.gitCommitKey: 7]
        XCTAssertEqual(AppInfo.versionDescription(infoDictionary: info), "1.2.0")
        XCTAssertEqual(AppInfo.versionDescription(infoDictionary: ["CFBundleShortVersionString": 1.2]), "dev")
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
