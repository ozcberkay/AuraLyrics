import XCTest

final class LyricsViewTests: XCTestCase {

    // UIPX-03: LyricsView must branch at the .loaded case level on isSynced
    //          providing a plain ScrollView path for unsynced lyrics
    // RED: Current implementation uses a single ScrollViewReader path for both synced and unsynced
    func testLyricsViewUnsyncedBranch() throws {
        let sourceURL = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()   // AuraLyricsTests/
            .deletingLastPathComponent()   // Tests/
            .deletingLastPathComponent()   // project root
            .appendingPathComponent("AuraLyrics/Views/LyricsView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        XCTAssertTrue(source.contains("if lyricsManager.isSynced"),
                      "UIPX-03: LyricsView must have an explicit top-level if/else branch on lyricsManager.isSynced in the .loaded case to provide separate synced and unsynced scroll paths")
    }

    // UIPX-03 regression guard: Synced path must still use ScrollViewReader and onChange
    // PASS: These exist in the current implementation and must be preserved after the fix
    func testLyricsViewSyncedBranchPreserved() throws {
        let sourceURL = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()   // AuraLyricsTests/
            .deletingLastPathComponent()   // Tests/
            .deletingLastPathComponent()   // project root
            .appendingPathComponent("AuraLyrics/Views/LyricsView.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        XCTAssertTrue(source.contains("ScrollViewReader"),
                      "UIPX-03: Synced lyrics path must use ScrollViewReader for auto-scroll to active line")
        XCTAssertTrue(source.contains(".onChange"),
                      "UIPX-03: Synced lyrics path must use .onChange to react to activeLineID changes and scroll to active line")
    }
}
