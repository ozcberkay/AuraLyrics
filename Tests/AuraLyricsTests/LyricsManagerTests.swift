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
        // The fetch goes through LyricsCache.load, which calls the Core loadState.
        let cache = try String(contentsOf: sourceURL.deletingLastPathComponent()
            .deletingLastPathComponent().deletingLastPathComponent()
            .appendingPathComponent("AuraLyricsCore/LyricsCache.swift"), encoding: .utf8)
        XCTAssertTrue(
            source.contains("lyricsCache.load("),
            "LyricsManager must fetch through LyricsCache.load"
        )
        XCTAssertTrue(
            cache.contains("fetcher.loadState("),
            "LyricsCache must map fetch results to LyricsState through the Core loadState (notFound, instrumental, error)"
        )
    }

    /// The error state offers a Retry button. Source inspection because the views need AppKit.
    func testErrorStateRetryIsWired() throws {
        let root = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
        let manager = try String(contentsOf: root.appendingPathComponent("AuraLyrics/Services/LyricsManager.swift"), encoding: .utf8)
        XCTAssertTrue(manager.contains("func retry()"), "LyricsManager must expose retry()")
        XCTAssertTrue(manager.contains("fetchLyrics(for: lastState, forceRefresh: true)"),
                      "retry() must bypass a cached \"no lyrics\" answer")
        for view in ["LyricsView", "AuraView"] {
            let source = try String(contentsOf: root.appendingPathComponent("AuraLyrics/Views/\(view).swift"), encoding: .utf8)
            XCTAssertTrue(source.contains("lyricsManager.retry()"), "\(view) must call lyricsManager.retry() from its error state")
        }
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
        // A cancelled fetch must write neither lyrics nor an error message. The cache
        // lookup is synchronous now, so the network result is the only write after an await.
        XCTAssertEqual(
            source.components(separatedBy: "guard !Task.isCancelled else { return }").count - 1, 1,
            "the state write after the fetch await must be guarded"
        )
        guard let cancel = source.range(of: "fetchTask?.cancel()"),
              let lookup = source.range(of: "lyricsCache.cachedState(") else {
            return XCTFail("fetchLyrics must cancel and then check the cache")
        }
        XCTAssertLessThan(cancel.lowerBound, lookup.lowerBound,
                          "the previous fetch must be cancelled before the cache check")
    }

    /// LRC files mark instrumental breaks with blank timestamped lines. Selecting one as the
    /// active line blanks the middle of Aura mode, which reads as a broken app.
    /// The skipping itself is behaviour-tested in AuraLyricsCoreTests; this checks
    /// updateActiveLine still goes through it.
    func testActiveLineSkipsBlankEntries() throws {
        let sourceURL = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("AuraLyrics/Services/LyricsManager.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        guard let start = source.range(of: "func updateActiveLine()") else {
            return XCTFail("LyricsManager must have updateActiveLine()")
        }
        let body = source[start.upperBound...].prefix(600)
        XCTAssertTrue(
            body.contains("activeLine(at:"),
            "updateActiveLine must use activeLine(at:) so a blank gap holds the last sung line"
        )
    }
}
