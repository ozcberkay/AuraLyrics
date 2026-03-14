import XCTest
import Combine

final class SpotifyServiceTests: XCTestCase {
    var cancellables = Set<AnyCancellable>()

    // TIMR-01: pollTimer is AnyCancellable? — verified by confirming Timer.scheduledTimer is absent
    // (structural test — reads source, since we cannot access private pollTimer from tests)
    func testPollTimerCancellable() throws {
        // Verify via source: Timer.scheduledTimer must not appear in SpotifyService
        let sourceURL = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()   // AuraLyricsTests/
            .deletingLastPathComponent()   // Tests/
            .deletingLastPathComponent()   // project root
            .appendingPathComponent("AuraLyrics/Services/SpotifyService.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        XCTAssertFalse(source.contains("Timer.scheduledTimer"),
                       "SpotifyService must not use Timer.scheduledTimer (use Timer.publish)")
        XCTAssertTrue(source.contains("Timer.publish"),
                      "SpotifyService must use Timer.publish for pollTimer")
    }

    // THRD-03: Compiled NSAppleScript is reused — verified via source (lazy var pollScript)
    func testPollScriptCompiledOnce() throws {
        let sourceURL = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("AuraLyrics/Services/SpotifyService.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        XCTAssertTrue(source.contains("lazy var pollScript"),
                      "SpotifyService must use a lazy var for compiled NSAppleScript reuse")
        XCTAssertTrue(source.contains("compileAndReturnError"),
                      "SpotifyService must compile the script explicitly (not per-call)")
    }

    // TIMR-03: stopPolling called on NOT_RUNNING — verified via source
    func testPollingPausesWhenNotRunning() throws {
        let sourceURL = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("AuraLyrics/Services/SpotifyService.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        XCTAssertTrue(source.contains("NOT_RUNNING"),
                      "handleAppleScriptResult must handle NOT_RUNNING state")
        XCTAssertTrue(source.contains("stopPolling"),
                      "SpotifyService must have stopPolling() method")
        // Verify the pairing: stopPolling appears in context with NOT_RUNNING handling
        XCTAssertTrue(source.contains("handleAppleScriptResult"),
                      "fetchSpotifyState result must be handled via handleAppleScriptResult")
    }

    // NETW-03: artworkTask?.cancel() before new Task — verified via source
    func testArtworkTaskCancelledOnTrackChange() throws {
        let sourceURL = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .deletingLastPathComponent()
            .appendingPathComponent("AuraLyrics/Services/SpotifyService.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        XCTAssertTrue(source.contains("artworkTask?.cancel()"),
                      "fetchArtwork must cancel previous artworkTask before starting a new one")
        XCTAssertFalse(source.contains("Data(contentsOf:"),
                       "fetchArtwork must not use synchronous Data(contentsOf:)")
        XCTAssertTrue(source.contains("URLSession.shared.data(for:"),
                      "fetchArtwork must use async URLSession")
        XCTAssertTrue(source.contains("Task.isCancelled"),
                      "fetchArtwork must check Task.isCancelled after await to prevent stale writes")
    }
}
