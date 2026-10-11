import XCTest
@testable import AuraLyricsCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

/// Walks the LRCLIB fallback chain against a mock that answers by path and query.
final class LyricsFallbackTests: XCTestCase {

    private final class SleepRecorder: @unchecked Sendable {
        private let lock = NSLock()
        private var _delays: [UInt64] = []
        var delays: [UInt64] { lock.lock(); defer { lock.unlock() }; return _delays }
        func record(_ delay: UInt64) { lock.lock(); _delays.append(delay); lock.unlock() }
    }

    /// One recorded request: its path ("/api/get" or "/api/search") and query items.
    private struct Call {
        let path: String
        let query: [String: String]
    }

    private let sleeps = SleepRecorder()

    private static func call(_ request: URLRequest) -> Call {
        let components = request.url.flatMap { URLComponents(url: $0, resolvingAgainstBaseURL: false) }
        let query = Dictionary((components?.queryItems ?? []).map { ($0.name, $0.value ?? "") }, uniquingKeysWith: { a, _ in a })
        return Call(path: components?.path ?? "", query: query)
    }

    /// Routes every request through `handler`; anything it returns nil for gets the
    /// default "nothing here" answer: 404 for a get, an empty array for a search.
    private func route(_ handler: @escaping (Call) -> (Int, Data)?) {
        MockURLProtocol.reset { request in
            let call = Self.call(request)
            if let answer = handler(call) { return answer }
            return call.path == "/api/search" ? (200, Data("[]".utf8)) : (404, Data())
        }
    }

    private var calls: [Call] { MockURLProtocol.requests.map(Self.call) }

    private func load(_ track: String, _ artist: String, album: String = "", duration: Double = 200) async -> LyricsState? {
        let recorder = sleeps
        let fetcher = LyricsFetcher(session: MockURLProtocol.session(), sleep: { recorder.record($0) })
        return await fetcher.loadState(track: track, artist: artist, album: album, duration: duration)
    }

    private static func json(_ object: Any) -> Data {
        try! JSONSerialization.data(withJSONObject: object)
    }

    private static func record(_ track: String, _ artist: String, duration: Double = 200,
                               synced: String? = "[00:01.00]synced line", plain: String? = nil,
                               instrumental: Bool = false) -> [String: Any] {
        var r: [String: Any] = ["trackName": track, "artistName": artist, "duration": duration, "instrumental": instrumental]
        if let synced { r["syncedLyrics"] = synced }
        if let plain { r["plainLyrics"] = plain }
        return r
    }

    private func assertNoDuplicateURLs(file: StaticString = #filePath, line: UInt = #line) {
        let urls = MockURLProtocol.requests.compactMap(\.url)
        XCTAssertEqual(Set(urls).count, urls.count, "a URL was sent twice", file: file, line: line)
    }

    private func texts(_ state: LyricsState?) -> [String]? {
        guard case .loaded(let lines)? = state else { return nil }
        return lines.map(\.text)
    }

    // a. The exact get with album finds it: one request, nothing else.
    func testAlbumMatchOnFirstRequest() async {
        route { call in
            call.path == "/api/get" && call.query["album_name"] == "Müptezhel"
                ? (200, Self.json(Self.record("Akrep", "Ezhel"))) : nil
        }
        let state = await load("Akrep", "Ezhel", album: "Müptezhel")
        XCTAssertEqual(texts(state), ["synced line"])
        XCTAssertEqual(MockURLProtocol.requests.count, 1)
        XCTAssertTrue(sleeps.delays.isEmpty)
    }

    // b. A compilation album LRCLIB does not know: the album-less get finds the track.
    private let fortunate = ("Fortunate Son", "Creedence Clearwater Revival",
                             "The Long Road Home - The Ultimate John Fogerty / Creedence Collection")

    func testAlbumMissFallsBackToAlbumlessGet() async {
        route { call in
            guard call.path == "/api/get", call.query["album_name"] == nil else { return nil }
            return (200, Self.json(Self.record("Fortunate Son", "Creedence Clearwater Revival")))
        }
        let state = await load(fortunate.0, fortunate.1, album: fortunate.2)
        XCTAssertEqual(texts(state), ["synced line"])
        XCTAssertEqual(calls.map(\.path), ["/api/get", "/api/get"])
        XCTAssertEqual(calls[0].query["album_name"], fortunate.2)
        XCTAssertNil(calls[1].query["album_name"])
    }

    func testAlbumGetBusyFallsBackToAlbumlessGet() async {
        route { call in
            guard call.path == "/api/get" else { return nil }
            if call.query["album_name"] != nil { return (503, Data()) }
            return (200, Self.json(Self.record("Fortunate Son", "Creedence Clearwater Revival")))
        }
        let state = await load(fortunate.0, fortunate.1, album: fortunate.2)
        XCTAssertEqual(texts(state), ["synced line"])
        XCTAssertEqual(MockURLProtocol.requests.count, 4, "three 503 attempts, then the album-less get")
        XCTAssertEqual(sleeps.delays, [1_000_000_000, 1_000_000_000, 250_000_000])
    }

    // c. A remaster suffix hides the track until the title is cleaned.
    func testCleanedTitleIsTriedAfterOriginalFails() async {
        route { call in
            call.path == "/api/get" && call.query["track_name"] == "Come Together"
                ? (200, Self.json(Self.record("Come Together", "The Beatles"))) : nil
        }
        let state = await load("Come Together - Remastered 2009", "The Beatles", album: "Abbey Road (Remastered)")
        XCTAssertEqual(texts(state), ["synced line"])
        XCTAssertTrue(calls.contains { $0.path == "/api/get" && $0.query["track_name"] == "Come Together" })
        XCTAssertLessThanOrEqual(MockURLProtocol.requests.count, 6)
        assertNoDuplicateURLs()
    }

    // d. "feat." in the title and a joined artist string: only the first artist matches.
    func testFirstArtistIsTriedForMultiArtistTracks() async {
        route { call in
            if call.path == "/api/search" {
                // A non-empty but useless result, so no free-text search is needed.
                return (200, Self.json([Self.record("Other", "Nobody")]))
            }
            return call.query["artist_name"] == "Main" ? (200, Self.json(Self.record("Song", "Main"))) : nil
        }
        let state = await load("Song (feat. Guest)", "Main, Guest")
        XCTAssertEqual(texts(state), ["synced line"])
        XCTAssertTrue(calls.contains { $0.path == "/api/get" && $0.query["artist_name"] == "Main" && $0.query["track_name"] == "Song" })
        XCTAssertTrue(calls.contains { $0.query["track_name"] == "Song" && $0.query["artist_name"] == "Main, Guest" },
                      "the cleaned title was tried with the full artist first")
        XCTAssertLessThanOrEqual(MockURLProtocol.requests.count, 6)
        assertNoDuplicateURLs()
    }

    // e. Search results are only trusted within 3 s of the track's duration.
    private func searchOnly(duration: Double) {
        route { call in
            call.path == "/api/search" && call.query["track_name"] != nil
                ? (200, Self.json([Self.record("Song", "Band", duration: duration)])) : nil
        }
    }

    func testSearchResultTooFarOffInDurationIsRejected() async {
        searchOnly(duration: 203.5)
        let state = await load("Song", "Band", duration: 200)
        XCTAssertEqual(state, .notFound(track: "Song", artist: "Band"))
        XCTAssertEqual(calls.map(\.path), ["/api/get", "/api/search"])
    }

    func testSearchResultWithinThreeSecondsIsAccepted() async {
        searchOnly(duration: 202.5)
        let state = await load("Song", "Band", duration: 200)
        XCTAssertEqual(texts(state), ["synced line"])
    }

    func testEmptySearchFallsBackToFreeTextQuery() async {
        route { call in
            call.query["q"] == "Song Band" ? (200, Self.json([Self.record("Song", "Band")])) : nil
        }
        let state = await load("Song", "Band")
        XCTAssertEqual(texts(state), ["synced line"])
        XCTAssertEqual(calls.map(\.path), ["/api/get", "/api/search", "/api/search"])
    }

    // f. A plain-only get gets one search for a synced copy.
    func testPlainOnlyGetIsUpgradedToSyncedFromSearch() async {
        route { call in
            if call.path == "/api/get" { return (200, Self.json(Self.record("Song", "Band", synced: nil, plain: "plain line"))) }
            return (200, Self.json([Self.record("Song", "Band", synced: "[00:02.00]synced line")]))
        }
        let state = await load("Song", "Band")
        guard case .loaded(let lines)? = state else { return XCTFail("expected .loaded, got \(String(describing: state))") }
        XCTAssertEqual(lines.map(\.text), ["synced line"])
        XCTAssertTrue(lines.allSatisfy(\.isSynced))
        XCTAssertEqual(calls.map(\.path), ["/api/get", "/api/search"])
    }

    func testPlainOnlyGetIsKeptWhenSearchHasNoSyncedCopy() async {
        route { call in
            if call.path == "/api/get" { return (200, Self.json(Self.record("Song", "Band", synced: nil, plain: "plain line"))) }
            return (200, Self.json([Self.record("Song", "Band", synced: nil, plain: "other plain")]))
        }
        let state = await load("Song", "Band")
        guard case .loaded(let lines)? = state else { return XCTFail("expected .loaded, got \(String(describing: state))") }
        XCTAssertEqual(lines.map(\.text), ["plain line"])
        XCTAssertFalse(lines.contains(where: \.isSynced))
    }

    func testPlainOnlyGetIsKeptWhenUpgradeSearchFails() async {
        route { call in
            if call.path == "/api/get" { return (200, Self.json(Self.record("Song", "Band", synced: nil, plain: "plain line"))) }
            return (500, Data())
        }
        let state = await load("Song", "Band")
        XCTAssertEqual(texts(state), ["plain line"])
    }

    // g. Instrumental stops the chain on the spot.
    func testInstrumentalOnFirstStepStopsChain() async {
        route { _ in (200, Self.json(Self.record("Song", "Band", synced: nil, instrumental: true))) }
        let state = await load("Song (Live)", "A & B", album: "X")
        XCTAssertEqual(state, .instrumental(track: "Song (Live)", artist: "A & B"))
        XCTAssertEqual(MockURLProtocol.requests.count, 1)
    }

    // h. The budget of 6 requests holds even when many steps are possible.
    func testBudgetCapsRequestsWhenNothingIsFound() async {
        route { _ in nil }
        let state = await load("Song (Live)", "A & B", album: "X")
        XCTAssertEqual(state, .notFound(track: "Song (Live)", artist: "A & B"))
        XCTAssertEqual(MockURLProtocol.requests.count, 6)
        assertNoDuplicateURLs()
    }

    func testBudgetCapsRequestsWhenServerIsBusy() async {
        route { _ in (503, Data()) }
        let state = await load("Song (Live)", "A & B", album: "X")
        XCTAssertEqual(state, .error(LyricsFetcher.serverBusyMessage))
        XCTAssertEqual(MockURLProtocol.requests.count, 6)
        XCTAssertEqual(sleeps.delays, [1_000_000_000, 1_000_000_000, 250_000_000, 1_000_000_000, 1_000_000_000])
    }

    // One busy step moves on; the remaining steps find nothing, yet the call ends busy.
    func testSingleBusyStepMovesOnAndStillEndsBusy() async {
        route { call in call.query["album_name"] != nil ? (503, Data()) : nil }
        let state = await load("Song (Live)", "A & B", album: "X")
        XCTAssertEqual(state, .error(LyricsFetcher.serverBusyMessage))
        XCTAssertEqual(calls.map(\.path), ["/api/get", "/api/get", "/api/get", "/api/get", "/api/search", "/api/search"])
        XCTAssertEqual(sleeps.delays, [1_000_000_000, 1_000_000_000, 250_000_000, 250_000_000, 250_000_000])
    }

    // i. Requests are spaced out and never repeated.
    func testChainRequestsAreSpacedAndUnique() async {
        route { _ in nil }
        _ = await load("Song (Live)", "A & B", album: "X")
        XCTAssertGreaterThan(MockURLProtocol.requests.count, 1)
        XCTAssertTrue(sleeps.delays.contains(250_000_000))
        XCTAssertEqual(sleeps.delays.count, MockURLProtocol.requests.count - 1, "one wait before every request after the first")
        assertNoDuplicateURLs()
    }

    // j. Cancelling between steps (a track change) stops the chain.
    func testCancelBetweenStepsStopsChain() async {
        route { _ in nil }
        let fetcher = LyricsFetcher(session: MockURLProtocol.session(), sleep: { _ in
            try await Task.sleep(nanoseconds: 60_000_000_000)
        })
        let task = Task {
            await fetcher.loadState(track: "Song (Live)", artist: "A & B", album: "X", duration: 200)
        }
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
        XCTAssertEqual(MockURLProtocol.requests.count, 1)
    }

    // k. Cancelling during the synced-upgrade search must not return the plain lyrics.
    func testCancelDuringSyncedUpgradeSearchThrows() async {
        route { call in
            call.path == "/api/get"
                ? (200, Self.json(Self.record("Song", "Band", synced: nil, plain: "plain line"))) : nil
        }
        let fetcher = LyricsFetcher(session: MockURLProtocol.session(), sleep: { _ in
            try await Task.sleep(nanoseconds: 60_000_000_000)
        })
        // Two callers each send the plain-only get; both upgrade searches then block in the spacing sleep.
        let throwing = Task { try await fetcher.fetchLyrics(track: "Song", artist: "Band", album: "", duration: 200) }
        let state = Task { await fetcher.loadState(track: "Song", artist: "Band", album: "", duration: 200) }
        let deadline = Date().addingTimeInterval(5)
        while MockURLProtocol.requests.count < 2 {
            guard Date() < deadline else {
                throwing.cancel()
                state.cancel()
                return XCTFail("the get requests were not sent within 5 s")
            }
            try? await Task.sleep(nanoseconds: 5_000_000)
        }
        throwing.cancel()
        state.cancel()
        do {
            _ = try await throwing.value
            XCTFail("expected a cancellation error")
        } catch {
            XCTAssertTrue(error is CancellationError || (error as? URLError)?.code == .cancelled, "got \(error)")
        }
        let loaded = await state.value
        XCTAssertNil(loaded)
        XCTAssertEqual(calls.map(\.path), ["/api/get", "/api/get"], "no search request was sent")
    }
}
