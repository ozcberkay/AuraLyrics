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

    // ERRH-01 / ERRH-02: LyricsManager must use @Published var state: LyricsState (not lyrics+isLoading+error triple)
    // and handle both .notFound and .instrumental error cases
    func testLyricsManagerUsesLyricsState() throws {
        let sourceURL = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("AuraLyrics/Services/LyricsManager.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertTrue(
            source.contains("@Published var state: LyricsState"),
            "ERRH-01: LyricsManager must use @Published var state: LyricsState"
        )
        XCTAssertTrue(
            source.contains("case .notFound"),
            "ERRH-01: LyricsManager fetchLyrics must catch LyricsError.notFound and set .notFound state"
        )
        XCTAssertTrue(
            source.contains("case .instrumental"),
            "ERRH-02: LyricsManager fetchLyrics must catch LyricsError.instrumental and set .instrumental state"
        )
    }

    /// Skipping tracks quickly starts a second lyrics fetch while the first is still in
    /// flight. Nothing held the first task, so whichever response landed last won and the
    /// screen could end up showing the previous song's lyrics.
    func testFetchTaskIsRetainedAndCancelled() throws {
        let sourceURL = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("AuraLyrics/Services/LyricsManager.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)

        XCTAssertTrue(
            source.contains("private var fetchTask: Task<Void, Never>?"),
            "LyricsManager must hold the in-flight fetch so a new track can cancel it"
        )
        XCTAssertTrue(
            source.contains("fetchTask?.cancel()"),
            "fetchLyrics must cancel the previous fetch before starting a new one"
        )
        XCTAssertTrue(
            source.contains("fetchTask = Task {"),
            "the new fetch must be assigned to fetchTask, not started as a loose Task"
        )
        // A cancelled fetch must write neither lyrics nor an error message.
        XCTAssertEqual(
            source.components(separatedBy: "guard !Task.isCancelled else { return }").count - 1, 3,
            "each state write after an await must be guarded: disk cache, network success, catch"
        )
    }

    /// LRC files mark instrumental breaks with blank timestamped lines. Selecting one as the
    /// active line blanks the middle of Aura mode, which reads as a broken app.
    func testActiveLineSkipsBlankEntries() throws {
        let sourceURL = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("AuraLyrics/Services/LyricsManager.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        XCTAssertTrue(
            source.contains("$0.startTime <= currentPosition && !$0.text.isEmpty"),
            "updateActiveLine must skip blank lyric lines so a gap holds the last sung line"
        )
    }
}
