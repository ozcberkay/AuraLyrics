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
    private let retryDelays: [UInt64]

    /// `session` and `retryDelays` exist so tests can stub HTTP and skip the waits.
    /// The defaults are what the app uses: the shared session, then retries after 2 s and 5 s.
    public init(session: URLSession = .shared, retryDelays: [UInt64] = [2_000_000_000, 5_000_000_000]) {
        self.session = session
        self.retryDelays = retryDelays
    }

    // Retries only on transient URLErrors. Non-transient and non-URL errors propagate
    // immediately (a 404 is a response, not an error, so it is never retried).
    private func fetchWithRetry(request: URLRequest) async throws -> (Data, URLResponse) {
        var lastError: Error

        // First attempt
        do {
            return try await session.data(for: request)
        } catch let error as URLError {
            guard error.isTransient else { throw error }
            lastError = error
        }

        // Retry attempts
        for delay in retryDelays {
            try await Task.sleep(nanoseconds: delay)
            do {
                return try await session.data(for: request)
            } catch let error as URLError {
                guard error.isTransient else { throw error }
                lastError = error
            } catch {
                throw error  // Non-URLError (e.g. cancellation): don't retry
            }
        }
        throw lastError
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

        // 404 is intentionally NOT retried: fetchWithRetry only retries network errors
        if httpResponse.statusCode == 404 {
            throw LyricsError.notFound
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

            if let syncedLyrics = libResponse.syncedLyrics {
                let parseResult = LRCParser.parse(lrcContent: syncedLyrics)
                switch parseResult {
                case .success(let parsedLines): return parsedLines
                case .failure: throw LyricsError.decodeError
                }
            } else if let plainLyrics = libResponse.plainLyrics {
                // Split plain lyrics into lines to avoid truncation in UI
                return plainLyrics.components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                    .map { LyricsLine(id: UUID(), startTime: 0, text: $0, isSynced: false) }
            } else {
                return []
            }
        } catch {
            // Re-throw LyricsError cases directly (instrumental, notFound, etc.)
            if let lyricsError = error as? LyricsError {
                throw lyricsError
            }
            throw LyricsError.decodeError
        }
    }
}
