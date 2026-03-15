import XCTest

// AuraSizeManager lives in an executable target with dependencies: [] (no @testable import available).
// All tests use source-inspection via URL(fileURLWithPath: #file) + 3-level deletingLastPathComponent.

final class AuraSizeManagerTests: XCTestCase {

    private func auraSizeManagerSource() throws -> String {
        let sourceURL = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()   // AuraLyricsTests/
            .deletingLastPathComponent()   // Tests/
            .deletingLastPathComponent()   // project root
            .appendingPathComponent("AuraLyrics/Services/AuraSizeManager.swift")
        return try String(contentsOf: sourceURL, encoding: .utf8)
    }

    // OBSV-02: AuraSizeManager must NOT post NotificationCenter notifications.
    // WindowManager must subscribe via Combine $currentSize (an @Published property).
    // Manual NotificationCenter.default.post calls are redundant and must be removed.
    // Source-inspection test. Currently RED — existing code calls NotificationCenter.default.post
    // in the currentSize didSet observer.
    func testAuraSizeManagerDoesNotPostNotification() throws {
        let source = try auraSizeManagerSource()
        XCTAssertFalse(
            source.contains("NotificationCenter.default.post"),
            "OBSV-02: AuraSizeManager must not post NotificationCenter notifications — WindowManager subscribes via Combine $currentSize"
        )
        XCTAssertFalse(
            source.contains("auraSizeDidChange"),
            "OBSV-02: auraSizeDidChange notification name must be removed after Combine migration"
        )
    }
}
