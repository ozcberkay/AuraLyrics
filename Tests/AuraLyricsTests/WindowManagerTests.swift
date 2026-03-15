import XCTest

final class WindowManagerTests: XCTestCase {

    // UIPX-01: AppDefaults.Key must have listPanelFrame and auraPanelFrame cases
    // RED: AppDefaults.swift does not contain these keys yet
    func testWindowManagerFramePersistenceKeys() throws {
        let sourceURL = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()   // AuraLyricsTests/
            .deletingLastPathComponent()   // Tests/
            .deletingLastPathComponent()   // project root
            .appendingPathComponent("AuraLyrics/Models/AppDefaults.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        XCTAssertTrue(source.contains("listPanelFrame"),
                      "UIPX-01: AppDefaults.Key must have listPanelFrame case for window frame persistence")
        XCTAssertTrue(source.contains("auraPanelFrame"),
                      "UIPX-01: AppDefaults.Key must have auraPanelFrame case for window frame persistence")
    }

    // UIPX-01: WindowManager must conform to NSWindowDelegate and implement windowDidMove
    // RED: WindowManager.swift does not have NSWindowDelegate conformance or windowDidMove yet
    func testWindowManagerDelegatePattern() throws {
        let sourceURL = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()   // AuraLyricsTests/
            .deletingLastPathComponent()   // Tests/
            .deletingLastPathComponent()   // project root
            .appendingPathComponent("AuraLyrics/Services/WindowManager.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        XCTAssertTrue(source.contains("NSWindowDelegate"),
                      "UIPX-01: WindowManager must conform to NSWindowDelegate to receive move/resize callbacks")
        XCTAssertTrue(source.contains("windowDidMove"),
                      "UIPX-01: WindowManager must implement windowDidMove to persist frame on panel move")
    }

    // UIPX-01: WindowManager must restore frame from UserDefaults (NSRectFromString) and
    //          guard against off-screen placement (visibleFrame — Pitfall 2: disconnected monitor)
    // RED: WindowManager.swift does not have NSRectFromString or visibleFrame yet
    func testWindowManagerRestoreFrameGuard() throws {
        let sourceURL = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()   // AuraLyricsTests/
            .deletingLastPathComponent()   // Tests/
            .deletingLastPathComponent()   // project root
            .appendingPathComponent("AuraLyrics/Services/WindowManager.swift")
        let source = try String(contentsOf: sourceURL, encoding: .utf8)
        XCTAssertTrue(source.contains("NSRectFromString"),
                      "UIPX-01: WindowManager must use NSRectFromString to restore persisted frame from UserDefaults string")
        XCTAssertTrue(source.contains("visibleFrame"),
                      "UIPX-01: WindowManager must check visibleFrame to guard against off-screen placement (disconnected monitor)")
    }
}
