import Foundation

enum LyricsError: Error {
    case invalidURL
    case noData
    case decodeError
    case notFound
    case instrumental  // ERRH-02: lrclib.net returned instrumental=true
}

// NETW-04: transient URLError check — only these codes are worth retrying
private extension URLError {
    var isTransient: Bool {
        [.timedOut, .networkConnectionLost, .notConnectedToInternet,
         .cannotConnectToHost, .cannotLoadFromNetwork].contains(code)
    }
}

class LyricsFetcher {
    private let baseURL = "https://lrclib.net/api/get"

    // NETW-04: retry helper — retries only on transient URLErrors; non-transient and non-URL errors
    // propagate immediately (including LyricsError.notFound from 404, which is never retried).
    private func fetchWithRetry(request: URLRequest) async throws -> (Data, URLResponse) {
        let retryDelays: [UInt64] = [2_000_000_000, 5_000_000_000]  // 2s, 5s
        var lastError: Error

        // First attempt
        do {
            return try await URLSession.shared.data(for: request)
        } catch let error as URLError {
            guard error.isTransient else { throw error }
            lastError = error
        }

        // Retry attempts
        for delay in retryDelays {
            try await Task.sleep(nanoseconds: delay)
            do {
                return try await URLSession.shared.data(for: request)
            } catch let error as URLError {
                guard error.isTransient else { throw error }
                lastError = error
            } catch {
                throw error  // Non-URLError (e.g. cancellation): don't retry
            }
        }
        throw lastError
    }

    func fetchLyrics(track: String, artist: String, album: String, duration: Double) async throws -> [LyricsLine] {
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

        // NETW-02: explicit 10-second timeout on every URLRequest before sending
        var request = URLRequest(url: url)
        request.timeoutInterval = 10  // NETW-02: explicit 10-second timeout
        // lrclib.net asks clients to identify themselves so its maintainer can
        // contact the author of a misbehaving app instead of blocking it blindly.
        request.setValue(AppInfo.userAgent, forHTTPHeaderField: "User-Agent")

        let (data, response) = try await fetchWithRetry(request: request)

        guard let httpResponse = response as? HTTPURLResponse else {
            throw LyricsError.noData
        }

        // 404 is intentionally NOT retried — fetchWithRetry is only called for network errors
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

            // ERRH-02: instrumental check BEFORE synced/plain lyrics fallback
            if libResponse.instrumental == true {
                throw LyricsError.instrumental  // ERRH-02: caller sets .instrumental(track:artist:) state
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
