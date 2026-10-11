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

    // MARK: - In-memory NSCache for lyrics

    /// The memory cache lives in AuraLyricsCore's LyricsCache (behaviour-tested there);
    /// LyricsManager must route through it, and it must stay bounded at 50 entries.
    func testLyricsMemoryCachePresent() throws {
        let manager = try String(contentsOf: sourcePath("AuraLyrics/Services/LyricsManager.swift"), encoding: .utf8)
        let cache = try String(contentsOf: sourcePath("AuraLyricsCore/LyricsCache.swift"), encoding: .utf8)

        XCTAssertTrue(manager.contains("private let lyricsCache = LyricsCache("),
                      "LyricsManager must cache through the Core LyricsCache")
        XCTAssertTrue(cache.contains("lyricsMemoryCache"),
                      "LyricsCache must have a lyricsMemoryCache property")
        XCTAssertTrue(cache.contains("NSCache"),
                      "LyricsCache must use NSCache for in-memory caching")
        XCTAssertTrue(cache.contains("countLimit = 50"),
                      "The memory cache countLimit must be 50")
    }

    // MARK: - Disk cache in ~/Library/Caches/AuraLyrics/

    /// The disk cache must live in ~/Library/Caches/AuraLyrics/ as JSON files.
    func testDiskCachePresent() throws {
        let manager = try String(contentsOf: sourcePath("AuraLyrics/Services/LyricsManager.swift"), encoding: .utf8)
        let cache = try String(contentsOf: sourcePath("AuraLyricsCore/LyricsCache.swift"), encoding: .utf8)

        XCTAssertTrue(manager.contains(".cachesDirectory") && manager.contains("appendingPathComponent(\"AuraLyrics\""),
                      "LyricsManager must give LyricsCache the ~/Library/Caches/AuraLyrics directory")
        XCTAssertTrue(cache.contains("JSONEncoder"),
                      "LyricsCache must use JSONEncoder for disk serialization")
        XCTAssertTrue(cache.contains("func saveToDisk"),
                      "LyricsCache must have a saveToDisk function")
    }

    // MARK: - Artwork memory cache

    /// SpotifyService must have NSCache for artwork images with countLimit=20
    func testArtworkMemoryCachePresent() throws {
        let source = try String(contentsOf: sourcePath("AuraLyrics/Services/SpotifyService.swift"), encoding: .utf8)

        XCTAssertTrue(source.contains("artworkCache"),
                      "SpotifyService must have artworkCache property")
        XCTAssertTrue(source.contains("NSCache"),
                      "SpotifyService must use NSCache for artwork caching")
        XCTAssertTrue(source.contains("20"),
                      "Artwork NSCache countLimit must be 20")
    }

    // MARK: - Color cache for artwork average colors

    /// SpotifyService must cache computed artwork average colors
    func testColorCachePresent() throws {
        let source = try String(contentsOf: sourcePath("AuraLyrics/Services/SpotifyService.swift"), encoding: .utf8)

        XCTAssertTrue(source.contains("artworkAverageColor"),
                      "SpotifyService must have artworkAverageColor cache")
    }

    // MARK: - Adaptive polling interval

    /// SpotifyService must support adaptive polling intervals
    func testAdaptivePollingPresent() throws {
        let source = try String(contentsOf: sourcePath("AuraLyrics/Services/SpotifyService.swift"), encoding: .utf8)

        XCTAssertTrue(source.contains("currentPollInterval"),
                      "SpotifyService must have currentPollInterval property")
        XCTAssertTrue(source.contains("5.0"),
                      "SpotifyService adaptive polling must use 5.0s as a polling interval")
    }

    // MARK: - MenuBarManager NSHostingView rebuild prevention

    /// updateMenu() must NOT rebuild NSHostingView on every call, only create it once
    func testMenuNoHostingViewRebuild() throws {
        let source = try String(contentsOf: sourcePath("AuraLyrics/Services/MenuBarManager.swift"), encoding: .utf8)

        // Find the updateMenu() function body
        // Strategy: locate updateMenu() and check if NSHostingView is constructed there
        // After the fix, NSHostingView(rootView:) should NOT appear inside updateMenu()
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
                       "updateMenu() must not rebuild NSHostingView(rootView:) on every call, host view should be created once and reused")
    }

    // MARK: - Cache key identifies a recording, not a song title

    /// A live take, a remaster and the studio version of one song share a title and an
    /// artist but return different lyrics and timings from lrclib. The key itself is
    /// behaviour-tested in AuraLyricsCoreTests; this checks LyricsManager still uses it.
    func testCacheKeyIncludesAlbumAndDuration() throws {
        let source = try String(contentsOf: sourcePath("AuraLyrics/Services/LyricsManager.swift"), encoding: .utf8)
        XCTAssertTrue(
            source.contains("func cacheKey(for state: PlaybackState)"),
            "LyricsManager must build its cache key in one place"
        )
        XCTAssertTrue(
            source.contains("state.lyricsCacheKey"),
            "LyricsManager must route through PlaybackState.lyricsCacheKey, which includes album and duration"
        )
        XCTAssertFalse(
            source.contains("\"\\(playbackState.track)---\\(playbackState.artist)\""),
            "The old title+artist-only cache key must not come back"
        )
    }

    /// Track titles contain slashes, colons and, occasionally, enough characters to blow
    /// past the 255-byte filename limit. Hashing sidesteps all of it.
    func testDiskCacheFilenameIsHashed() throws {
        let source = try String(contentsOf: sourcePath("AuraLyrics/Services/LyricsManager.swift"), encoding: .utf8)
        XCTAssertTrue(
            source.contains("import CryptoKit") && source.contains("SHA256.hash"),
            "Disk cache filenames must be hashed rather than sanitised by hand"
        )
        XCTAssertTrue(
            source.contains("fileName: LyricsManager.hashedFileName"),
            "LyricsCache must be given the SHA256 file-name function"
        )
    }
}
