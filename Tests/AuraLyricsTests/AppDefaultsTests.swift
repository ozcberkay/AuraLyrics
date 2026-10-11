import XCTest

// AppDefaults lives in an executable target with dependencies: [] (no @testable import available).
// All tests use source-inspection via URL(fileURLWithPath: #file) + 3-level deletingLastPathComponent.

final class AppDefaultsTests: XCTestCase {

    // AppDefaults.swift must exist and define an enum Key with at least 3 cases:
    // auraSize, appTheme, and appMode (consolidated UserDefaults key constants).
    // Source-inspection test. Currently RED — AppDefaults.swift does not exist yet.
    func testAppDefaultsKeyEnumExists() throws {
        let sourceURL = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()   // AuraLyricsTests/
            .deletingLastPathComponent()   // Tests/
            .deletingLastPathComponent()   // project root
            .appendingPathComponent("AuraLyrics/Models/AppDefaults.swift")

        var source: String
        do {
            source = try String(contentsOf: sourceURL, encoding: .utf8)
        } catch {
            XCTFail("AppDefaults.swift must exist in AuraLyrics/Models/, file not found: \(error.localizedDescription)")
            return
        }

        XCTAssertTrue(
            source.contains("enum AppDefaults") || source.contains("struct AppDefaults"),
            "AppDefaults.swift must define an AppDefaults type"
        )
        XCTAssertTrue(
            source.contains("case auraSize"),
            "AppDefaults.Key must contain case auraSize"
        )
        XCTAssertTrue(
            source.contains("case appTheme"),
            "AppDefaults.Key must contain case appTheme"
        )
        XCTAssertTrue(
            source.contains("case appMode"),
            "AppDefaults.Key must contain case appMode"
        )
    }
}
