import XCTest
@testable import AuraLyricsCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Drives LyricsCache.load against the stubbed LRCLIB and counts requests to prove
/// when the cache answered and when it went to the network.
final class LyricsCacheTests: XCTestCase {

    /// A clock the test moves forward by hand.
    private final class Clock: @unchecked Sendable {
        private let lock = NSLock()
        private var _now = Date(timeIntervalSince1970: 1_000_000)
        var now: Date { lock.lock(); defer { lock.unlock() }; return _now }
        func advance(_ seconds: TimeInterval) { lock.lock(); _now += seconds; lock.unlock() }
    }

    private var directory: URL!
    private let clock = Clock()

    override func setUp() {
        super.setUp()
        directory = FileManager.default.temporaryDirectory.appendingPathComponent(UUID().uuidString)
    }

    override func tearDown() {
        try? FileManager.default.removeItem(at: directory)
        super.tearDown()
    }

    /// File names stay readable in tests; the app passes a SHA256 digest instead.
    private static func fileName(_ key: String) -> String {
        key.replacingOccurrences(of: ":", with: "_").replacingOccurrences(of: "/", with: "_")
    }

    /// A fresh cache over the same directory, like the app after a relaunch.
    private func makeCache() -> LyricsCache {
        let clock = self.clock
        return LyricsCache(directory: directory, fileName: Self.fileName, now: { clock.now })
    }

    private let fetcher = LyricsFetcher(session: MockURLProtocol.session(), sleep: { _ in })

    private func playback(_ track: String = "Song", artist: String = "Band", album: String = "Studio",
                          duration: TimeInterval = 200, trackID: String = "spotify:track:abc") -> PlaybackState {
        PlaybackState(track: track, artist: artist, album: album, isPlaying: true, position: 0,
                      duration: duration, artworkUrl: "", isSpotifyRunning: true,
                      timestamp: Date(), trackID: trackID)
    }

    private static let lyricsBody = try! JSONSerialization.data(withJSONObject: [
        "trackName": "Song", "artistName": "Band", "duration": 200, "instrumental": false,
        "syncedLyrics": "[00:01.00]synced line",
    ])

    /// Every get finds the lyrics.
    private func serveLyrics() { MockURLProtocol.reset { _ in (200, Self.lyricsBody) } }

    /// Nothing anywhere: 404 for a get, an empty list for a search.
    private func serveNothing() {
        MockURLProtocol.reset { request in
            request.url?.path == "/api/search" ? (200, Data("[]".utf8)) : (404, Data())
        }
    }

    private func texts(_ state: LyricsState?) -> [String]? {
        guard case .loaded(let lines)? = state else { return nil }
        return lines.map(\.text)
    }

    private func file(for key: String) -> URL {
        directory.appendingPathComponent(Self.fileName(key) + ".json")
    }

    // a. Same track id, different metadata: served from the cache.
    func testSameTrackIDWithDifferentMetadataIsServedFromCache() async {
        serveLyrics()
        let cache = makeCache()
        let first = await cache.load(playback(), fetcher: fetcher)
        XCTAssertEqual(texts(first), ["synced line"])
        XCTAssertEqual(MockURLProtocol.requests.count, 1)

        let renamed = playback("Song - Remastered", artist: "The Band", album: "Best Of", duration: 203)
        let second = await cache.load(renamed, fetcher: fetcher)
        XCTAssertEqual(texts(second), ["synced line"])
        XCTAssertEqual(MockURLProtocol.requests.count, 1, "no request for a known track id")

        // Survives a relaunch too: a new cache over the same directory reads the file.
        let third = await makeCache().load(renamed, fetcher: fetcher)
        XCTAssertEqual(texts(third), ["synced line"])
        XCTAssertEqual(MockURLProtocol.requests.count, 1)
    }

    // b. A miss stored less than 24 hours ago answers without a request.
    func testFreshMissIsServedFromCache() async {
        serveNothing()
        let first = await makeCache().load(playback(), fetcher: fetcher)
        XCTAssertEqual(first, .notFound(track: "Song", artist: "Band"))
        let sent = MockURLProtocol.requests.count
        XCTAssertGreaterThan(sent, 0)

        clock.advance(23 * 60 * 60)
        // A new cache, so the answer comes from the disk file, not memory.
        let second = await makeCache().load(playback(), fetcher: fetcher)
        XCTAssertEqual(second, .notFound(track: "Song", artist: "Band"))
        XCTAssertEqual(MockURLProtocol.requests.count, sent, "a fresh miss must not hit LRCLIB again")
    }

    func testFreshInstrumentalIsServedFromCache() async {
        MockURLProtocol.reset { _ in
            (200, try JSONSerialization.data(withJSONObject: [
                "trackName": "Song", "artistName": "Band", "duration": 200, "instrumental": true,
            ]))
        }
        let cache = makeCache()
        let first = await cache.load(playback(), fetcher: fetcher)
        XCTAssertEqual(first, .instrumental(track: "Song", artist: "Band"))
        XCTAssertEqual(MockURLProtocol.requests.count, 1)

        clock.advance(60)
        let second = await cache.load(playback(), fetcher: fetcher)
        XCTAssertEqual(second, .instrumental(track: "Song", artist: "Band"))
        XCTAssertEqual(MockURLProtocol.requests.count, 1)
    }

    // c. A miss older than 24 hours is treated as absent: LRCLIB is asked again.
    func testExpiredMissTriggersNewRequest() async {
        serveNothing()
        let cache = makeCache()
        _ = await cache.load(playback(), fetcher: fetcher)
        let sent = MockURLProtocol.requests.count

        clock.advance(24 * 60 * 60 + 1)
        serveLyrics()
        let memory = await cache.load(playback(), fetcher: fetcher)
        XCTAssertEqual(texts(memory), ["synced line"])
        XCTAssertEqual(MockURLProtocol.requests.count, 1, "the expired miss sent a new request")
        XCTAssertGreaterThan(sent, 0)
    }

    func testExpiredMissOnDiskTriggersNewRequest() async {
        serveNothing()
        _ = await makeCache().load(playback(), fetcher: fetcher)

        clock.advance(25 * 60 * 60)
        serveNothing()
        let state = await makeCache().load(playback(), fetcher: fetcher)
        XCTAssertEqual(state, .notFound(track: "Song", artist: "Band"))
        XCTAssertGreaterThan(MockURLProtocol.requests.count, 0, "the expired miss on disk sent a new request")
    }

    // d. A transient error is written nowhere; the next load asks again.
    func testTransientErrorIsNotCached() async {
        MockURLProtocol.reset { _ in throw URLError(.notConnectedToInternet) }
        let cache = makeCache()
        let first = await cache.load(playback(), fetcher: fetcher)
        guard case .error? = first else { return XCTFail("expected .error, got \(String(describing: first))") }
        XCTAssertNil(cache.cachedState(for: "spotify:track:abc"), "nothing in memory")
        XCTAssertFalse(FileManager.default.fileExists(atPath: file(for: "spotify:track:abc").path), "nothing on disk")

        serveLyrics()
        let second = await cache.load(playback(), fetcher: fetcher)
        XCTAssertEqual(texts(second), ["synced line"])
        XCTAssertEqual(MockURLProtocol.requests.count, 1)
    }

    func testBadResponseErrorIsNotCached() async {
        MockURLProtocol.reset { _ in (403, Data()) }
        let cache = makeCache()
        let state = await cache.load(playback(), fetcher: fetcher)
        XCTAssertEqual(state, .error(LyricsFetcher.genericErrorMessage))
        XCTAssertNil(cache.cachedState(for: "spotify:track:abc"), "nothing in memory")
        XCTAssertFalse(FileManager.default.fileExists(atPath: file(for: "spotify:track:abc").path), "nothing on disk")
    }

    func testStoreIgnoresErrorAndPlaceholderStates() {
        let cache = makeCache()
        for state in [LyricsState.error("x"), .idle, .loading] {
            cache.store(state, for: "k")
            XCTAssertNil(cache.cachedState(for: "k"))
        }
        XCTAssertFalse(FileManager.default.fileExists(atPath: directory.path))
    }

    // e. Forced refresh (Retry) asks LRCLIB even with a fresh miss cached.
    func testForcedRefreshBypassesFreshMiss() async {
        serveNothing()
        let cache = makeCache()
        _ = await cache.load(playback(), fetcher: fetcher)

        serveLyrics()
        let retried = await cache.load(playback(), fetcher: fetcher, forceRefresh: true)
        XCTAssertEqual(texts(retried), ["synced line"])
        XCTAssertEqual(MockURLProtocol.requests.count, 1)

        // The retry's result is cached by the same rules: found lyrics stay.
        let again = await makeCache().load(playback(), fetcher: fetcher)
        XCTAssertEqual(texts(again), ["synced line"])
        XCTAssertEqual(MockURLProtocol.requests.count, 1)
    }

    func testForcedRefreshThatErrorsLeavesNothingCached() async {
        serveNothing()
        let cache = makeCache()
        _ = await cache.load(playback(), fetcher: fetcher)

        MockURLProtocol.reset { _ in throw URLError(.timedOut) }
        _ = await cache.load(playback(), fetcher: fetcher, forceRefresh: true)
        XCTAssertNil(cache.cachedState(for: "spotify:track:abc"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: file(for: "spotify:track:abc").path))
    }

    // A cancelled fetch returns nil and caches nothing.
    func testCancelledFetchReturnsNilAndCachesNothing() async {
        serveNothing()
        let cache = makeCache()
        let slow = LyricsFetcher(session: MockURLProtocol.session(), sleep: { _ in
            try await Task.sleep(nanoseconds: 60_000_000_000)
        })
        let task = Task { await cache.load(playback(), fetcher: slow) }
        let deadline = Date().addingTimeInterval(5)
        while MockURLProtocol.requests.isEmpty {
            guard Date() < deadline else {
                task.cancel()
                return XCTFail("no request was sent within 5 s")
            }
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        task.cancel()
        let state = await task.value
        XCTAssertNil(state)
        XCTAssertNil(cache.cachedState(for: "spotify:track:abc"), "nothing in memory")
        XCTAssertFalse(FileManager.default.fileExists(atPath: file(for: "spotify:track:abc").path), "nothing on disk")
    }

    // A served miss shows the current playback's names, not the ones stored with it.
    func testServedMissCarriesCurrentTrackAndArtist() async {
        serveNothing()
        let cache = makeCache()
        _ = await cache.load(playback(), fetcher: fetcher)
        let renamed = playback("Song - Remastered", artist: "The Band")
        let served = await cache.load(renamed, fetcher: fetcher)
        XCTAssertEqual(served, .notFound(track: "Song - Remastered", artist: "The Band"))
        XCTAssertEqual(cache.cachedState(for: renamed),
                       .notFound(track: "Song - Remastered", artist: "The Band"))
    }

    // f. Old-format files load as lyrics; broken files count as absent.
    func testOldFormatFileLoadsAsLyrics() throws {
        let lines = [LyricsLine(id: UUID(), startTime: 1, text: "old line", isSynced: true)]
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try JSONEncoder().encode(lines).write(to: file(for: "old"))
        XCTAssertEqual(makeCache().cachedState(for: "old"), .loaded(lines))
    }

    func testCorruptEmptyOrUnknownFilesAreAbsent() throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        let bodies: [String: Data] = [
            "empty": Data(),
            "garbage": Data("not json at all {".utf8),
            "object": Data("{}".utf8),
            "unknown": Data(#"{"something":"else"}"#.utf8),
            "number": Data("42".utf8),
            "wrongArray": Data(#"[{"x":1}]"#.utf8),
            "missWithoutDate": Data(#"{"miss":"notFound","track":"S","artist":"B"}"#.utf8),
        ]
        let cache = makeCache()
        for (key, body) in bodies {
            try body.write(to: file(for: key))
            XCTAssertNil(cache.cachedState(for: key), "\(key) must count as absent")
        }
    }

    func testCorruptFileIsReplacedByFetch() async throws {
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        try Data("garbage".utf8).write(to: file(for: "spotify:track:abc"))
        serveLyrics()
        let state = await makeCache().load(playback(), fetcher: fetcher)
        XCTAssertEqual(texts(state), ["synced line"])
        XCTAssertEqual(MockURLProtocol.requests.count, 1)
        XCTAssertNotNil(makeCache().cachedState(for: "spotify:track:abc"))
    }

    func testRemoveDropsMemoryAndDisk() async {
        serveLyrics()
        let cache = makeCache()
        _ = await cache.load(playback(), fetcher: fetcher)
        cache.remove("spotify:track:abc")
        XCTAssertNil(cache.cachedState(for: "spotify:track:abc"))
        XCTAssertFalse(FileManager.default.fileExists(atPath: file(for: "spotify:track:abc").path))
    }
}
