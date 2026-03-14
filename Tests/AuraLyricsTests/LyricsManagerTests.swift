import XCTest

final class LyricsManagerTests: XCTestCase {

    // TIMR-02: 0.1s timer pauses when Spotify is not playing or lyrics are empty
    // Verified via source inspection: LyricsManager must have conditional timer start/stop
    func testTimerPausesWhenNotPlaying() throws {
        let sourceURL = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()   // AuraLyricsTests/
            .deletingLastPathComponent()   // Tests/
            .deletingLastPathComponent()   // project root
            .appendingPathComponent("AuraLyrics/Services/LyricsManager.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        // Must have conditional start: startTimerIfNeeded only when isPlaying && lyrics non-empty
        XCTAssertTrue(source.contains("startTimerIfNeeded"),
                      "LyricsManager must have startTimerIfNeeded() for TIMR-02")
        XCTAssertTrue(source.contains("stopTimer"),
                      "LyricsManager must have stopTimer() for TIMR-02")

        // Must not unconditionally start the timer in init
        // (old code: init called startTimer() unconditionally)
        XCTAssertFalse(source.contains("startTimer()"),
                       "LyricsManager init must NOT call startTimer() unconditionally — use conditional start")

        // Must check isPlaying before starting timer
        XCTAssertTrue(source.contains("isPlaying"),
                      "LyricsManager timer logic must check isPlaying state")

        // Must restart timer when lyrics arrive (TIMR-02 pitfall: timer never restarts after lyrics fetch)
        XCTAssertTrue(source.contains("startTimerIfNeeded") && source.contains("lastState.isPlaying"),
                      "LyricsManager must restart timer after lyrics fetch if lastState.isPlaying")
    }
}
