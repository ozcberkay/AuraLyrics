import XCTest
@testable import AuraLyricsCore
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

final class LyricsFetcherTests: XCTestCase {

    private func makeFetcher() -> LyricsFetcher {
        LyricsFetcher(session: MockURLProtocol.session(), retryDelays: [0, 0])
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
        XCTAssertEqual(query["duration"], "215", "duration is sent as a whole number of seconds")
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
    }

    func testNotFoundIsNotRetried() async {
        MockURLProtocol.reset { _ in (404, Data()) }
        let error = await fetchError()
        XCTAssertEqual(error as? LyricsError, .notFound)
        XCTAssertEqual(MockURLProtocol.requests.count, 1)
    }

    func testServerErrorThrowsNoData() async {
        MockURLProtocol.reset { _ in (500, Data()) }
        let error = await fetchError()
        XCTAssertEqual(error as? LyricsError, .noData)
    }

    func testTransientErrorIsRetried() async throws {
        MockURLProtocol.reset { _ in
            if MockURLProtocol.requests.count == 1 { throw URLError(.timedOut) }
            return (200, self.json(["plainLyrics": "back online"]))
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

    func testInvalidJSONThrowsDecodeError() async {
        MockURLProtocol.reset { _ in (200, Data("not json".utf8)) }
        let error = await fetchError()
        XCTAssertEqual(error as? LyricsError, .decodeError)
    }
}
