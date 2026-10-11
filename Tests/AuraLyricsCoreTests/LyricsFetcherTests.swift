import XCTest
@testable import AuraLyricsCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class LyricsFetcherTests: XCTestCase {

    /// Collects every wait the fetcher asks for, without actually waiting.
    private final class SleepRecorder: @unchecked Sendable {
        private let lock = NSLock()
        private var _delays: [UInt64] = []
        var delays: [UInt64] { lock.lock(); defer { lock.unlock() }; return _delays }
        func record(_ delay: UInt64) { lock.lock(); _delays.append(delay); lock.unlock() }
    }

    private let sleeps = SleepRecorder()

    private func makeFetcher() -> LyricsFetcher {
        let recorder = sleeps
        return LyricsFetcher(session: MockURLProtocol.session(), sleep: { recorder.record($0) })
    }

    private func loadState() async -> LyricsState? {
        await makeFetcher().loadState(track: "Song", artist: "Band", album: "Live at Home", duration: 215.7)
    }

    private func sequence(_ responses: [(Int, [String: String])], then final: (Int, Data)) -> MockURLProtocol.HeaderHandler {
        return { _ in
            let index = MockURLProtocol.requests.count - 1
            if index < responses.count { return (responses[index].0, responses[index].1, Data()) }
            return (final.0, [:], final.1)
        }
    }

    private func fetch() async throws -> [LyricsLine] {
        try await makeFetcher().fetchLyrics(track: "Song", artist: "Band", album: "Live at Home", duration: 215.7)
    }

    private func json(_ object: [String: Any]) -> Data {
        try! JSONSerialization.data(withJSONObject: object)
    }

    /// Runs `fetch()` and returns the error it throws, failing if it succeeds.
    private func fetchError(file: StaticString = #filePath, line: UInt = #line) async -> Error? {
        do {
            _ = try await fetch()
            XCTFail("fetchLyrics was expected to throw", file: file, line: line)
            return nil
        } catch {
            return error
        }
    }

    func testRequestCarriesQueryTimeoutAndUserAgent() async throws {
        MockURLProtocol.reset { _ in (200, self.json(["plainLyrics": "a"])) }
        _ = try await fetch()

        let request = try XCTUnwrap(MockURLProtocol.requests.first)
        let components = try XCTUnwrap(URLComponents(url: XCTUnwrap(request.url), resolvingAgainstBaseURL: false))
        let query = Dictionary(uniqueKeysWithValues: (components.queryItems ?? []).map { ($0.name, $0.value ?? "") })
        XCTAssertEqual(components.host, "lrclib.net")
        XCTAssertEqual(components.path, "/api/get")
        XCTAssertEqual(query["track_name"], "Song")
        XCTAssertEqual(query["artist_name"], "Band")
        XCTAssertEqual(query["album_name"], "Live at Home")
        XCTAssertEqual(query["duration"], "215.7", "duration is sent as decimal seconds")
        XCTAssertEqual(request.timeoutInterval, 10)
        XCTAssertEqual(request.value(forHTTPHeaderField: "User-Agent"), AppInfo.userAgent)
    }

    func testSyncedLyricsAreParsedAndSorted() async throws {
        let lrc = "[00:05.00]second\n[00:01.50]first"
        MockURLProtocol.reset { _ in (200, self.json(["syncedLyrics": lrc, "plainLyrics": "ignored"])) }
        let lines = try await fetch()

        XCTAssertEqual(lines.map(\.text), ["first", "second"])
        XCTAssertEqual(lines.map(\.startTime), [1.5, 5.0])
        XCTAssertTrue(lines.allSatisfy(\.isSynced))
    }

    func testPlainLyricsFallbackDropsBlankLines() async throws {
        MockURLProtocol.reset { _ in (200, self.json(["plainLyrics": "one\n\n  two  \n   \nthree"])) }
        let lines = try await fetch()

        XCTAssertEqual(lines.map(\.text), ["one", "two", "three"])
        XCTAssertTrue(lines.allSatisfy { !$0.isSynced && $0.startTime == 0 })
    }

    func testInstrumentalThrowsInstrumental() async {
        MockURLProtocol.reset { _ in (200, self.json(["instrumental": true, "plainLyrics": "la la"])) }
        let error = await fetchError()
        XCTAssertEqual(error as? LyricsError, .instrumental)
        XCTAssertEqual(MockURLProtocol.requests.count, 1)
    }

    private var requestPaths: [String] { MockURLProtocol.requests.map { $0.url?.path ?? "" } }

    func testNotFoundIsNotRetried() async {
        MockURLProtocol.reset { _ in (404, Data()) }
        let error = await fetchError()
        XCTAssertEqual(error as? LyricsError, .notFound)
        // Each chain step is sent once: album get, album-less get, search. No retries.
        XCTAssertEqual(requestPaths, ["/api/get", "/api/get", "/api/search"])
        XCTAssertEqual(Set(MockURLProtocol.requests.compactMap(\.url)).count, 3)
    }

    func testServerErrorStopsChainOnSecondBusyStepWithoutRetry() async {
        MockURLProtocol.reset { _ in (500, Data()) }
        let error = await fetchError()
        XCTAssertEqual(error as? LyricsError, .serverUnavailable)
        XCTAssertEqual(MockURLProtocol.requests.count, 2)
        XCTAssertEqual(sleeps.delays, [250_000_000], "only the spacing between steps, no retry wait")
    }

    func testOtherStatusMovesOnAndEndsBadResponse() async {
        MockURLProtocol.reset { _ in (403, Data()) }
        let error = await fetchError()
        XCTAssertEqual(error as? LyricsError, .badResponse)
        XCTAssertEqual(MockURLProtocol.requests.count, 3)
    }

    func testBadStatusOnEveryStepGivesGenericErrorState() async {
        MockURLProtocol.reset { _ in (403, Data()) }
        let state = await loadState()
        XCTAssertEqual(state, .error(LyricsFetcher.genericErrorMessage))
    }

    func testNotFoundOnEveryStepGivesNotFoundState() async {
        MockURLProtocol.reset { _ in (404, Data()) }
        let state = await loadState()
        XCTAssertEqual(state, .notFound(track: "Song", artist: "Band"))
    }

    func testRateLimitWithoutRetryAfterIsNotRetriedAndEndsBusy() async {
        MockURLProtocol.reset { _ in (429, Data()) }
        let state = await loadState()
        XCTAssertEqual(state, .error(LyricsFetcher.serverBusyMessage))
        XCTAssertEqual(MockURLProtocol.requests.count, 1)
        XCTAssertTrue(sleeps.delays.isEmpty, "no retry wait and no spacing")
    }

    func testRateLimitWithoutRetryAfterAfterRetriedServerErrorIsNotRetried() async {
        MockURLProtocol.resetWithHeaders(handler: sequence([(503, [:])], then: (429, Data())))
        let state = await loadState()
        XCTAssertEqual(state, .error(LyricsFetcher.serverBusyMessage))
        XCTAssertEqual(MockURLProtocol.requests.count, 2, "the 503 is retried once, the 429 is not")
        XCTAssertEqual(sleeps.delays, [1_000_000_000], "only the 503 retry wait")
    }

    func testRateLimitWithRetryAfterOneSecondIsRetried() async throws {
        MockURLProtocol.resetWithHeaders(handler: sequence([(429, ["Retry-After": "1"])], then: (200, json(["syncedLyrics": "[00:01.00]ok"]))))
        let lines = try await fetch()
        XCTAssertEqual(lines.map(\.text), ["ok"])
        XCTAssertEqual(MockURLProtocol.requests.count, 2)
        XCTAssertEqual(sleeps.delays, [1_000_000_000])
    }

    func testBadResponseOnEarlyStepStillLoadsLaterLyrics() async throws {
        MockURLProtocol.reset { request in
            request.url?.path == "/api/get" ? (403, Data()) : (200, try! JSONSerialization.data(withJSONObject: [["syncedLyrics": "[00:01.00]found", "trackName": "Song", "artistName": "Band", "duration": 215.7]]))
        }
        let lines = try await fetch()
        XCTAssertEqual(lines.map(\.text), ["found"])
        XCTAssertEqual(requestPaths, ["/api/get", "/api/get", "/api/search"])
    }

    func testRetriesOn503WithDefaultOneSecondWait() async throws {
        MockURLProtocol.resetWithHeaders(handler: sequence([(503, [:])], then: (200, json(["syncedLyrics": "[00:01.00]ok"]))))
        let lines = try await fetch()
        XCTAssertEqual(lines.map(\.text), ["ok"])
        XCTAssertEqual(MockURLProtocol.requests.count, 2)
        XCTAssertEqual(sleeps.delays, [1_000_000_000])
    }

    func testRetriesOn503HonouringRetryAfter() async throws {
        MockURLProtocol.resetWithHeaders(handler: sequence([(503, ["Retry-After": "2"])], then: (200, json(["syncedLyrics": "[00:01.00]ok"]))))
        _ = try await fetch()
        XCTAssertEqual(sleeps.delays, [2_000_000_000])
    }

    func testRetriesOn429HonouringRetryAfter() async throws {
        MockURLProtocol.resetWithHeaders(handler: sequence([(429, ["Retry-After": "3"])], then: (200, json(["syncedLyrics": "[00:01.00]ok"]))))
        _ = try await fetch()
        XCTAssertEqual(MockURLProtocol.requests.count, 2)
        XCTAssertEqual(sleeps.delays, [3_000_000_000])
    }

    func testRetryAfterIsCappedAtFiveSeconds() async throws {
        MockURLProtocol.resetWithHeaders(handler: sequence([(503, ["Retry-After": "30"])], then: (200, json(["syncedLyrics": "[00:01.00]ok"]))))
        _ = try await fetch()
        XCTAssertEqual(sleeps.delays, [5_000_000_000])
    }

    func testUnparseableRetryAfterFallsBackToOneSecond() async throws {
        MockURLProtocol.resetWithHeaders(handler: sequence([(503, ["Retry-After": "Wed, 21 Oct 2026 07:28:00 GMT"])], then: (200, json(["syncedLyrics": "[00:01.00]ok"]))))
        _ = try await fetch()
        XCTAssertEqual(sleeps.delays, [1_000_000_000])
    }

    func testAll503sGiveServerUnavailableStateWithinBudget() async {
        MockURLProtocol.reset { _ in (503, Data()) }
        let state = await loadState()
        XCTAssertEqual(state, .error(LyricsFetcher.serverBusyMessage))
        // Two busy steps of three attempts each fill the budget of 6 and stop the chain.
        XCTAssertEqual(MockURLProtocol.requests.count, 6)
        XCTAssertEqual(sleeps.delays, [1_000_000_000, 1_000_000_000, 250_000_000, 1_000_000_000, 1_000_000_000])
    }

    func testUrlErrorsAndHttpRetriesShareOneBudget() async {
        MockURLProtocol.resetWithHeaders(handler: { _ in
            if MockURLProtocol.requests.count == 1 { throw URLError(.timedOut) }
            return (503, [:], Data())
        })
        let state = await loadState()
        XCTAssertEqual(state, .error(LyricsFetcher.serverBusyMessage))
        XCTAssertEqual(MockURLProtocol.requests.count, 6)
        XCTAssertEqual(sleeps.delays, [2_000_000_000, 1_000_000_000, 250_000_000, 1_000_000_000, 1_000_000_000])
    }

    func testThreeUrlErrorsGiveNetworkErrorState() async {
        MockURLProtocol.reset { _ in throw URLError(.notConnectedToInternet) }
        let state = await loadState()
        XCTAssertEqual(state, .error(LyricsFetcher.networkErrorMessage))
        XCTAssertEqual(MockURLProtocol.requests.count, 3, "a dead network stops the chain after the first step")
        XCTAssertEqual(sleeps.delays, [2_000_000_000, 5_000_000_000])
    }

    func testNotFoundStateWithoutRetryWaits() async {
        MockURLProtocol.reset { _ in (404, Data()) }
        let state = await loadState()
        XCTAssertEqual(state, .notFound(track: "Song", artist: "Band"))
        XCTAssertEqual(MockURLProtocol.requests.count, 3)
        XCTAssertEqual(sleeps.delays, [250_000_000, 250_000_000], "only the spacing between chain steps")
    }

    func testInstrumentalState() async {
        MockURLProtocol.reset { _ in (200, self.json(["instrumental": true])) }
        let state = await loadState()
        XCTAssertEqual(state, .instrumental(track: "Song", artist: "Band"))
    }

    func testDecodeFailureMovesOnAndEndsGenericError() async {
        MockURLProtocol.reset { _ in (200, Data("not json".utf8)) }
        let state = await loadState()
        XCTAssertEqual(state, .error(LyricsFetcher.genericErrorMessage))
        XCTAssertEqual(MockURLProtocol.requests.count, 3)
    }

    func testNonTransientErrorGivesGenericError() async {
        MockURLProtocol.reset { _ in throw URLError(.badURL) }
        let state = await loadState()
        XCTAssertEqual(state, .error(LyricsFetcher.genericErrorMessage))
    }

    func testEmptyBodyIsNotFound() async {
        MockURLProtocol.reset { request in (200, request.url?.path == "/api/search" ? Data("[]".utf8) : self.json([:])) }
        let error = await fetchError()
        XCTAssertEqual(error as? LyricsError, .notFound)
    }

    func testLyricsParsingToZeroLinesIsNotFound() async {
        MockURLProtocol.reset { request in (200, request.url?.path == "/api/search" ? Data("[]".utf8) : self.json(["plainLyrics": " \n \n"])) }
        let error = await fetchError()
        XCTAssertEqual(error as? LyricsError, .notFound)
    }

    func testSuccessLoadsState() async {
        MockURLProtocol.reset { _ in (200, self.json(["plainLyrics": "la"])) }
        guard case .loaded(let lines)? = await loadState() else { return XCTFail("expected .loaded") }
        XCTAssertEqual(lines.map(\.text), ["la"])
    }

    func testCancelledFetchReturnsNilAndSendsNoFurtherRequest() async {
        MockURLProtocol.reset { _ in (503, Data()) }
        let fetcher = LyricsFetcher(session: MockURLProtocol.session(), sleep: { _ in
            try await Task.sleep(nanoseconds: 60_000_000_000)
        })
        let task = Task {
            await fetcher.loadState(track: "Song", artist: "Band", album: "Live at Home", duration: 215.7)
        }
        // Wait until the first request is out, so the fetcher is parked inside its sleep.
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

    func testTransientErrorIsRetried() async throws {
        MockURLProtocol.reset { _ in
            if MockURLProtocol.requests.count == 1 { throw URLError(.timedOut) }
            return (200, self.json(["syncedLyrics": "[00:01.00]back online"]))
        }
        let lines = try await fetch()
        XCTAssertEqual(lines.map(\.text), ["back online"])
        XCTAssertEqual(MockURLProtocol.requests.count, 2)
    }

    func testNonTransientErrorIsNotRetried() async {
        MockURLProtocol.reset { _ in throw URLError(.badURL) }
        let error = await fetchError()
        XCTAssertEqual((error as? URLError)?.code, .badURL)
        XCTAssertEqual(MockURLProtocol.requests.count, 1)
    }

    func testGivesUpAfterThreeTransientFailures() async {
        MockURLProtocol.reset { _ in throw URLError(.networkConnectionLost) }
        let error = await fetchError()
        XCTAssertEqual((error as? URLError)?.code, .networkConnectionLost)
        XCTAssertEqual(MockURLProtocol.requests.count, 3)
    }

    func testInvalidJSONOnEveryStepEndsBadResponse() async {
        MockURLProtocol.reset { _ in (200, Data("not json".utf8)) }
        let error = await fetchError()
        XCTAssertEqual(error as? LyricsError, .badResponse)
    }
}
