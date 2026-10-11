import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif
#if canImport(os)
import os
#endif

public enum LyricsError: Error, Sendable {
    case invalidURL
    case noData
    case decodeError
    case notFound
    case instrumental  // lrclib.net returned instrumental=true
    case serverUnavailable  // 503/429 after retries, or any other 5xx
    case badResponse  // 403, another unexpected 4xx or non-200 status, or a 200 that is not valid JSON
    case rateLimited  // 429 without Retry-After: retrying would only make it worse
}

// Only these URLError codes are worth retrying; everything else fails immediately.
private extension URLError {
    var isTransient: Bool {
        [.timedOut, .networkConnectionLost, .notConnectedToInternet,
         .cannotConnectToHost, .cannotLoadFromNetwork].contains(code)
    }
}

// Sendable: every stored property is immutable and Sendable, so instances are safe
// to hand to a Task. Without this, Swift 6 language mode rejects LyricsManager
// passing `fetcher` across an isolation boundary.
public final class LyricsFetcher: Sendable {
    private static let getURL = "https://lrclib.net/api/get"
    private static let searchURL = "https://lrclib.net/api/search"
    private let session: URLSession
    private let sleep: @Sendable (UInt64) async throws -> Void

    /// Waits before retrying a transient URLError: first retry after 2 s, second after 5 s.
    private static let transientDelays: [UInt64] = [2_000_000_000, 5_000_000_000]
    /// URLErrors and HTTP 503/429 responses share this one budget per fetch.
    private static let maxRetries = 2
    private static let defaultRetryAfter: UInt64 = 1
    private static let maxRetryAfter: UInt64 = 5
    /// Hard cap on HTTP requests per `fetchLyrics` call, retries included.
    private static let maxRequests = 6
    /// Minimum wait before every request after the first, so the chain never bursts LRCLIB.
    private static let requestSpacing: UInt64 = 250_000_000

    /// Per-call state of the fallback chain: the original query, requests sent, URLs tried.
    private struct Chain {
        let track: String
        let artist: String
        let duration: Double
        var sent = 0
        var urls = Set<URL>()
    }

    private struct BudgetExhausted: Error {}

    /// Logs only the status (or "decode failed") and the endpoint path: never the query,
    /// the track, the artist or the lyrics.
    private static func logBad(_ what: String, path: String) {
        #if canImport(os)
        logger.error("LRCLIB \(what, privacy: .public) on \(path, privacy: .public)")
        #endif
    }
    #if canImport(os)
    private static let logger = Logger(subsystem: Bundle.main.bundleIdentifier ?? "com.auralyrics", category: "lyrics")
    #endif

    private enum Step {
        case get(String, String, String)  // title, artist, album ("" leaves album out)
        case search(String, String)  // title, artist
    }

    /// User-facing messages for `LyricsState.error`, shared by the app and the tests.
    public static let networkErrorMessage = "Can't reach LRCLIB. Check your connection."
    public static let serverBusyMessage = "LRCLIB is busy right now."
    public static let genericErrorMessage = "Couldn't load lyrics."

    /// `session` and `sleep` exist so tests can stub HTTP and measure the waits without
    /// waiting. The defaults are what the app uses: the shared session and a real sleep.
    public init(
        session: URLSession = .shared,
        sleep: @escaping @Sendable (UInt64) async throws -> Void = { try await Task.sleep(nanoseconds: $0) }
    ) {
        self.session = session
        self.sleep = sleep
    }

    /// Whole seconds from the Retry-After header (integer form only), default 1 s, capped at 5 s.
    private static func retryAfterDelay(_ response: HTTPURLResponse) -> UInt64 {
        let header = response.value(forHTTPHeaderField: "Retry-After")?.trimmingCharacters(in: .whitespaces)
        let seconds = header.flatMap { UInt64($0) } ?? defaultRetryAfter
        return min(seconds, maxRetryAfter) * 1_000_000_000
    }

    // Retries transient URLErrors and HTTP 503/429, at most `maxRetries` times in total.
    // A 429 without a Retry-After header is not retried: it throws `rateLimited` at once.
    // Everything else propagates immediately (a 404 is a response, not an error, so it is
    // never retried). Cancellation stops the loop: the sleep throws, and a sleeper that
    // returns anyway is caught by the explicit check before the next request.
    // Every send, retries included, counts against the chain's request budget, and every
    // send after the first of the call waits `requestSpacing` unless a retry wait just ran.
    private func fetchWithRetry(request: URLRequest, chain: inout Chain) async throws -> (Data, URLResponse) {
        var retries = 0
        var waited = false
        var lastFailure: Error?
        while true {
            // Out of budget mid-retry: report what the last attempt failed with.
            guard chain.sent < Self.maxRequests else { throw lastFailure ?? BudgetExhausted() }
            if chain.sent > 0 && !waited {
                try await sleep(Self.requestSpacing)
                try Task.checkCancellation()
            }
            chain.sent += 1
            let delay: UInt64
            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse, http.statusCode == 503 || http.statusCode == 429 else {
                    return (data, response)
                }
                if http.statusCode == 429 && http.value(forHTTPHeaderField: "Retry-After") == nil {
                    Self.logBad("status 429", path: request.url?.path ?? "")
                    throw LyricsError.rateLimited
                }
                guard retries < Self.maxRetries else { throw LyricsError.serverUnavailable }
                lastFailure = LyricsError.serverUnavailable
                delay = Self.retryAfterDelay(http)
            } catch let error as URLError where error.isTransient {
                guard retries < Self.maxRetries else { throw error }
                lastFailure = error
                delay = Self.transientDelays[retries]
            }
            retries += 1
            try await sleep(delay)
            try Task.checkCancellation()
            waited = true
        }
    }

    /// Fetches lyrics and maps the outcome to a `LyricsState`. Returns nil when the fetch
    /// ended because it was cancelled, so the caller leaves the screen alone.
    public func loadState(track: String, artist: String, album: String, duration: Double) async -> LyricsState? {
        do {
            let lines = try await fetchLyrics(track: track, artist: artist, album: album, duration: duration)
            return Task.isCancelled ? nil : .loaded(lines)
        } catch {
            if error is CancellationError || (error as? URLError)?.code == .cancelled || Task.isCancelled {
                return nil
            }
            switch error {
            case LyricsError.notFound: return .notFound(track: track, artist: artist)
            case LyricsError.instrumental: return .instrumental(track: track, artist: artist)
            case LyricsError.serverUnavailable: return .error(Self.serverBusyMessage)
            case let urlError as URLError where urlError.isTransient: return .error(Self.networkErrorMessage)
            default: return .error(Self.genericErrorMessage)
            }
        }
    }

    /// Walks the LRCLIB fallback chain until a step finds lyrics. A missing or empty answer
    /// and an unreadable lyrics text move on to the next step. So does a bad response (403,
    /// another unexpected status, a 200 that is not JSON), and if nothing is found after one
    /// the call throws `badResponse` instead of `notFound`. A busy server moves on once and
    /// stops the chain the second time. A 429 without Retry-After stops the chain at once as
    /// busy. A network failure, an instrumental track or cancellation ends the call right away.
    public func fetchLyrics(track: String, artist: String, album: String, duration: Double) async throws -> [LyricsLine] {
        var chain = Chain(track: track, artist: artist, duration: duration)
        var busySteps = 0
        var badSteps = 0
        loop: for step in Self.steps(track: track, artist: artist, album: album) {
            do {
                switch step {
                case let .get(title, artist, album):
                    return try await get(title: title, artist: artist, album: album, chain: &chain)
                case let .search(title, artist):
                    return try await search(title: title, artist: artist, chain: &chain)
                }
            } catch is BudgetExhausted {
                break loop
            } catch LyricsError.rateLimited {
                throw LyricsError.serverUnavailable
            } catch LyricsError.badResponse {
                badSteps += 1
            } catch LyricsError.serverUnavailable {
                busySteps += 1
                if busySteps == 2 { break loop }
            } catch LyricsError.notFound, LyricsError.noData, LyricsError.decodeError {
                continue
            }
        }
        if busySteps > 0 { throw LyricsError.serverUnavailable }
        throw badSteps > 0 ? LyricsError.badResponse : LyricsError.notFound
    }

    /// The fallback order: every exact get first (with album, album-less, cleaned title, first
    /// of several artists), then the searches in the same order.
    // A get is one request while a search can cost two (free-text fallback), so trying every
    // exact get first reaches the first-artist step inside the request budget even after retries.
    private static func steps(track: String, artist: String, album: String) -> [Step] {
        var steps: [Step] = [.get(track, artist, album)]
        if !album.isEmpty { steps.append(.get(track, artist, "")) }
        let cleaned = LyricsMatching.cleanTitle(track)
        if let cleaned { steps.append(.get(cleaned, artist, "")) }
        let artists = LyricsMatching.splitArtists(artist)
        let multi = artists.count > 1
        if multi { steps.append(.get(cleaned ?? track, artists[0], "")) }
        steps.append(.search(track, artist))
        if let cleaned { steps.append(.search(cleaned, artist)) }
        if multi { steps.append(.search(cleaned ?? track, artists[0])) }
        return steps
    }

    /// `/api/get` needs an exact match. A plain-only hit gets one search for a synced copy
    /// of the same track; if that search fails the plain lyrics are still returned.
    private func get(title: String, artist: String, album: String, chain: inout Chain) async throws -> [LyricsLine] {
        var items = [URLQueryItem(name: "track_name", value: title), URLQueryItem(name: "artist_name", value: artist)]
        if !album.isEmpty { items.append(URLQueryItem(name: "album_name", value: album)) }
        items.append(URLQueryItem(name: "duration", value: Self.durationString(chain.duration)))
        let response = try Self.decode(LRCLibResponse.self, from: try await send(Self.getURL, items, chain: &chain), path: "/api/get")
        let lines = try Self.lines(from: response)
        guard (response.syncedLyrics ?? "").isEmpty else { return lines }

        let query = [URLQueryItem(name: "track_name", value: title), URLQueryItem(name: "artist_name", value: artist)]
        var results: [LRCLibResponse]?
        do {
            results = try await searchResults(query, chain: &chain)
        } catch is CancellationError {
            throw CancellationError()
        } catch let error as URLError where error.code == .cancelled {
            throw error
        } catch {
            results = nil  // any other failure keeps the plain lyrics
        }
        if let results,
           let best = LyricsMatching.pickBest(results, title: chain.track, artist: chain.artist, duration: chain.duration),
           !(best.syncedLyrics ?? "").isEmpty,
           let synced = try? Self.lines(from: best) {
            return synced
        }
        return lines
    }

    /// Searches by title and artist, falls back to a free-text query when that returns
    /// nothing, and keeps the best match for the track the caller asked for.
    private func search(title: String, artist: String, chain: inout Chain) async throws -> [LyricsLine] {
        var results = try await searchResults(
            [URLQueryItem(name: "track_name", value: title), URLQueryItem(name: "artist_name", value: artist)], chain: &chain)
        if results.isEmpty {
            results = try await searchResults([URLQueryItem(name: "q", value: "\(title) \(artist)")], chain: &chain)
        }
        guard let best = LyricsMatching.pickBest(results, title: chain.track, artist: chain.artist, duration: chain.duration) else {
            throw LyricsError.notFound
        }
        return try Self.lines(from: best)
    }

    private func searchResults(_ items: [URLQueryItem], chain: inout Chain) async throws -> [LRCLibResponse] {
        try Self.decode([LRCLibResponse].self, from: try await send(Self.searchURL, items, chain: &chain), path: "/api/search")
    }

    /// Sends one request and returns the body of a 200. A URL already tried in this call
    /// is skipped as not found instead of being sent again.
    private func send(_ base: String, _ items: [URLQueryItem], chain: inout Chain) async throws -> Data {
        var urlComponents = URLComponents(string: base)!
        urlComponents.queryItems = items
        guard let url = urlComponents.url else {
            throw LyricsError.invalidURL
        }
        guard chain.urls.insert(url).inserted else { throw LyricsError.notFound }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10  // explicit 10-second timeout on every request
        // lrclib.net asks clients to identify themselves so its maintainer can
        // contact the author of a misbehaving app instead of blocking it blindly.
        request.setValue(AppInfo.userAgent, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await fetchWithRetry(request: request, chain: &chain)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LyricsError.noData
        }

        // 404 is intentionally NOT retried: fetchWithRetry only retries network errors and 503/429
        if httpResponse.statusCode == 404 {
            throw LyricsError.notFound
        }

        if (500...599).contains(httpResponse.statusCode) {
            throw LyricsError.serverUnavailable
        }

        guard httpResponse.statusCode == 200 else {
            Self.logBad("status \(httpResponse.statusCode)", path: url.path)
            throw LyricsError.badResponse
        }
        return data
    }

    private static func decode<T: Decodable>(_ type: T.Type, from data: Data, path: String) throws -> T {
        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase
        do {
            return try decoder.decode(type, from: data)
        } catch {
            logBad("decode failed", path: path)
            throw LyricsError.badResponse
        }
    }

    /// Seconds rounded to milliseconds, without trailing zeros: 215.7 -> "215.7", 215.0 -> "215".
    private static func durationString(_ duration: Double) -> String {
        let text = String((duration * 1000).rounded() / 1000)
        return text.hasSuffix(".0") ? String(text.dropLast(2)) : text
    }

    /// Turns one LRCLIB record into lines: synced first, plain as a fallback.
    private static func lines(from response: LRCLibResponse) throws -> [LyricsLine] {
        // Instrumental check comes before the synced/plain lyrics fallback
        if response.instrumental == true {
            throw LyricsError.instrumental  // caller sets the .instrumental(track:artist:) state
        }

        let lines: [LyricsLine]
        if let syncedLyrics = response.syncedLyrics, !syncedLyrics.isEmpty {
            switch LRCParser.parse(lrcContent: syncedLyrics) {
            case .success(let parsedLines): lines = parsedLines
            case .failure: throw LyricsError.decodeError
            }
        } else if let plainLyrics = response.plainLyrics {
            // Split plain lyrics into lines to avoid truncation in UI
            lines = plainLyrics.components(separatedBy: .newlines)
                .map { $0.trimmingCharacters(in: .whitespaces) }
                .filter { !$0.isEmpty }
                .map { LyricsLine(id: UUID(), startTime: 0, text: $0, isSynced: false) }
        } else {
            lines = []
        }
        // An empty result is "no lyrics", not a successful load worth caching.
        if lines.isEmpty { throw LyricsError.notFound }
        return lines
    }
}
