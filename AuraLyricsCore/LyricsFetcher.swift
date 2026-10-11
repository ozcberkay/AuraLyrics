import Foundation
#if canImport(FoundationNetworking)
import FoundationNetworking
#endif

public enum LyricsError: Error, Sendable {
    case invalidURL
    case noData
    case decodeError
    case notFound
    case instrumental  // lrclib.net returned instrumental=true
    case serverUnavailable  // 503/429 after retries, or any other 5xx
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
    private let baseURL = "https://lrclib.net/api/get"
    private let session: URLSession
    private let sleep: @Sendable (UInt64) async throws -> Void

    /// Waits before retrying a transient URLError: first retry after 2 s, second after 5 s.
    private static let transientDelays: [UInt64] = [2_000_000_000, 5_000_000_000]
    /// URLErrors and HTTP 503/429 responses share this one budget per fetch.
    private static let maxRetries = 2
    private static let defaultRetryAfter: UInt64 = 1
    private static let maxRetryAfter: UInt64 = 5

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
    // Everything else propagates immediately (a 404 is a response, not an error, so it is
    // never retried). Cancellation stops the loop: the sleep throws, and a sleeper that
    // returns anyway is caught by the explicit check before the next request.
    private func fetchWithRetry(request: URLRequest) async throws -> (Data, URLResponse) {
        var retries = 0
        while true {
            let delay: UInt64
            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse, http.statusCode == 503 || http.statusCode == 429 else {
                    return (data, response)
                }
                guard retries < Self.maxRetries else { throw LyricsError.serverUnavailable }
                delay = Self.retryAfterDelay(http)
            } catch let error as URLError where error.isTransient {
                guard retries < Self.maxRetries else { throw error }
                delay = Self.transientDelays[retries]
            }
            retries += 1
            try await sleep(delay)
            try Task.checkCancellation()
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

    public func fetchLyrics(track: String, artist: String, album: String, duration: Double) async throws -> [LyricsLine] {
        var urlComponents = URLComponents(string: baseURL)!
        urlComponents.queryItems = [
            URLQueryItem(name: "track_name", value: track),
            URLQueryItem(name: "artist_name", value: artist),
            URLQueryItem(name: "album_name", value: album),
            URLQueryItem(name: "duration", value: String(Int(duration)))
        ]

        guard let url = urlComponents.url else {
            throw LyricsError.invalidURL
        }

        var request = URLRequest(url: url)
        request.timeoutInterval = 10  // explicit 10-second timeout on every request
        // lrclib.net asks clients to identify themselves so its maintainer can
        // contact the author of a misbehaving app instead of blocking it blindly.
        request.setValue(AppInfo.userAgent, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await fetchWithRetry(request: request)

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
            throw LyricsError.noData
        }

        let decoder = JSONDecoder()
        decoder.keyDecodingStrategy = .convertFromSnakeCase

        do {
            let libResponse = try decoder.decode(LRCLibResponse.self, from: data)

            // Instrumental check comes before the synced/plain lyrics fallback
            if libResponse.instrumental == true {
                throw LyricsError.instrumental  // caller sets the .instrumental(track:artist:) state
            }

            let lines: [LyricsLine]
            if let syncedLyrics = libResponse.syncedLyrics {
                let parseResult = LRCParser.parse(lrcContent: syncedLyrics)
                switch parseResult {
                case .success(let parsedLines): lines = parsedLines
                case .failure: throw LyricsError.decodeError
                }
            } else if let plainLyrics = libResponse.plainLyrics {
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
        } catch {
            // Re-throw LyricsError cases directly (instrumental, notFound, etc.)
            if let lyricsError = error as? LyricsError {
                throw lyricsError
            }
            throw LyricsError.decodeError
        }
    }
}
