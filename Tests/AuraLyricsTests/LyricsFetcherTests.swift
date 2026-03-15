import XCTest

// LyricsFetcher lives in an executable target with dependencies: [] (no @testable import available).
// All tests use source-inspection via URL(fileURLWithPath: #file) + 3-level deletingLastPathComponent.

final class LyricsFetcherTests: XCTestCase {

    private func lyricsFetcherSource() throws -> String {
        let sourceURL = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()   // AuraLyricsTests/
            .deletingLastPathComponent()   // Tests/
            .deletingLastPathComponent()   // project root
            .appendingPathComponent("AuraLyrics/Services/LyricsFetcher.swift")
        return try String(contentsOf: sourceURL, encoding: .utf8)
    }

    // NETW-02: LyricsFetcher must configure an explicit timeout on URLRequest.
    // Source-inspection test. Currently RED — existing code uses URLSession.shared.data(from: url)
    // with no URLRequest, so timeoutInterval is never set.
    func testRequestHasExplicitTimeout() throws {
        let source = try lyricsFetcherSource()
        XCTAssertTrue(
            source.contains("timeoutInterval"),
            "NETW-02: LyricsFetcher must set timeoutInterval on URLRequest"
        )
        XCTAssertTrue(
            source.contains("timeoutInterval = 10"),
            "NETW-02: timeout must be 10 seconds per spec"
        )
    }

    // NETW-04: LyricsFetcher must implement retry logic with non-blocking backoff
    // and must only retry transient URLErrors (not 404).
    // Source-inspection test. Currently RED — existing code has no retry mechanism.
    func testRetryLogicPresent() throws {
        let source = try lyricsFetcherSource()
        XCTAssertTrue(
            source.contains("fetchWithRetry"),
            "NETW-04: LyricsFetcher must have fetchWithRetry function"
        )
        XCTAssertTrue(
            source.contains("Task.sleep"),
            "NETW-04: retry must use Task.sleep for non-blocking backoff delays"
        )
        XCTAssertTrue(
            source.contains("isTransient"),
            "NETW-04: retry must only retry transient URLErrors (not 404)"
        )
    }
}
