import XCTest

final class CachingTests: XCTestCase {

    // MARK: - Source Path Helper

    private func sourcePath(_ file: String) -> URL {
        URL(fileURLWithPath: #file)
            .deletingLastPathComponent()   // AuraLyricsTests/
            .deletingLastPathComponent()   // Tests/
            .deletingLastPathComponent()   // project root
            .appendingPathComponent(file)
    }

    // MARK: - CACH-01: In-memory NSCache for lyrics

    /// CACH-01: LyricsManager must have NSCache<NSString, CachedLyricsLines> with countLimit=50
    func testLyricsMemoryCachePresent() throws {
        let source = try String(contentsOf: sourcePath("AuraLyrics/Services/LyricsManager.swift"), encoding: .utf8)

        XCTAssertTrue(source.contains("lyricsMemoryCache"),
                      "CACH-01: LyricsManager must have lyricsMemoryCache property")
        XCTAssertTrue(source.contains("NSCache"),
                      "CACH-01: LyricsManager must use NSCache for in-memory caching")
        XCTAssertTrue(source.contains("countLimit"),
                      "CACH-01: NSCache must have countLimit set")
        XCTAssertTrue(source.contains("50"),
                      "CACH-01: NSCache countLimit must be 50")
    }

    // MARK: - CACH-02: Disk cache in ~/Library/Caches/AuraLyrics/

    /// CACH-02: LyricsManager must read/write ~/Library/Caches/AuraLyrics/*.json
    func testDiskCachePresent() throws {
        let source = try String(contentsOf: sourcePath("AuraLyrics/Services/LyricsManager.swift"), encoding: .utf8)

        XCTAssertTrue(source.contains("AuraLyrics"),
                      "CACH-02: LyricsManager must use 'AuraLyrics' as the cache subdirectory name")
        XCTAssertTrue(source.contains("JSONEncoder"),
                      "CACH-02: LyricsManager must use JSONEncoder for disk serialization")
        XCTAssertTrue(source.contains("saveLyricsToDisk") || source.contains("saveToDisk"),
                      "CACH-02: LyricsManager must have a saveLyricsToDisk or saveToDisk function")
    }

    // MARK: - CACH-03: Artwork memory cache (Plan 02)

    /// CACH-03: SpotifyService must have NSCache for artwork images with countLimit=20
    func testArtworkMemoryCachePresent() throws {
        let source = try String(contentsOf: sourcePath("AuraLyrics/Services/SpotifyService.swift"), encoding: .utf8)

        XCTAssertTrue(source.contains("artworkCache"),
                      "CACH-03: SpotifyService must have artworkCache property (Plan 02)")
        XCTAssertTrue(source.contains("NSCache"),
                      "CACH-03: SpotifyService must use NSCache for artwork caching (Plan 02)")
        XCTAssertTrue(source.contains("20"),
                      "CACH-03: Artwork NSCache countLimit must be 20 (Plan 02)")
    }

    // MARK: - CACH-04: Color cache for artwork average colors (Plan 02)

    /// CACH-04: SpotifyService must cache computed artwork average colors
    func testColorCachePresent() throws {
        let source = try String(contentsOf: sourcePath("AuraLyrics/Services/SpotifyService.swift"), encoding: .utf8)

        XCTAssertTrue(source.contains("artworkAverageColor"),
                      "CACH-04: SpotifyService must have artworkAverageColor cache (Plan 02)")
    }

    // MARK: - PERF-01: Adaptive polling interval (Plan 03)

    /// PERF-01: SpotifyService must support adaptive polling intervals
    func testAdaptivePollingPresent() throws {
        let source = try String(contentsOf: sourcePath("AuraLyrics/Services/SpotifyService.swift"), encoding: .utf8)

        XCTAssertTrue(source.contains("currentPollInterval"),
                      "PERF-01: SpotifyService must have currentPollInterval property (Plan 03)")
        XCTAssertTrue(source.contains("5.0"),
                      "PERF-01: SpotifyService adaptive polling must use 5.0s as a polling interval (Plan 03)")
    }

    // MARK: - PERF-02: MenuBarManager NSHostingView rebuild prevention (Plan 03)

    /// PERF-02: updateMenu() must NOT rebuild NSHostingView on every call — only create it once
    func testMenuNoHostingViewRebuild() throws {
        let source = try String(contentsOf: sourcePath("AuraLyrics/Services/MenuBarManager.swift"), encoding: .utf8)

        // Find the updateMenu() function body
        // Strategy: locate updateMenu() and check if NSHostingView is constructed there
        // After Plan 03 fix, NSHostingView(rootView:) should NOT appear inside updateMenu()
        let containsHostingViewInUpdateMenu: Bool = {
            // Extract the updateMenu function body
            guard let updateMenuRange = source.range(of: "func updateMenu()") else { return false }
            let afterUpdateMenu = String(source[updateMenuRange.upperBound...])
            // Find the next function definition to bound our search
            // Check if NSHostingView(rootView: appears before the next func
            if let nextFuncRange = afterUpdateMenu.range(of: "\n    func ") ?? afterUpdateMenu.range(of: "\n    private func ") {
                let updateMenuBody = String(afterUpdateMenu[..<nextFuncRange.lowerBound])
                return updateMenuBody.contains("NSHostingView(rootView:")
            }
            // If no next func found, search entire remainder
            return afterUpdateMenu.contains("NSHostingView(rootView:")
        }()

        XCTAssertFalse(containsHostingViewInUpdateMenu,
                       "PERF-02: updateMenu() must not rebuild NSHostingView(rootView:) on every call — host view should be created once and reused (Plan 03)")
    }
}
