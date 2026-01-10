import Foundation

enum LyricsError: Error {
    case invalidURL
    case noData
    case decodeError
    case notFound
}

class LyricsFetcher {
    private let baseURL = "https://lrclib.net/api/get"
    
    func fetchLyrics(track: String, artist: String, album: String, duration: Double) async throws -> [LyricsLine] {
        var urlComponents = URLComponents(string: baseURL)!
        urlComponents.queryItems = [
            URLQueryItem(name: "track_name", value: track),
            URLQueryItem(name: "artist_name", value: artist),
            URLQueryItem(name: "album_name", value: album),
            URLQueryItem(name: "duration", value: String(Int(duration)))
        ]
        
        print("[LyricsFetcher] Fetching: \(track) by \(artist) (Duration: \(Int(duration))s)")
        
        guard let url = urlComponents.url else {
            throw LyricsError.invalidURL
        }
        
        print("[LyricsFetcher] URL: \(url.absoluteString)")
        
        let (data, response) = try await URLSession.shared.data(from: url)
        
        guard let httpResponse = response as? HTTPURLResponse else {
            throw LyricsError.noData
        }
        
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
            if let syncedLyrics = libResponse.syncedLyrics {
                return LRCParser.parse(lrcContent: syncedLyrics)
            } else if let plainLyrics = libResponse.plainLyrics {
                // Split plain lyrics into lines to avoid truncation in UI
                return plainLyrics.components(separatedBy: .newlines)
                    .map { $0.trimmingCharacters(in: .whitespaces) }
                    .filter { !$0.isEmpty }
                    .map { LyricsLine(startTime: 0, text: $0, isSynced: false) }
            } else {
                return []
            }
        } catch {
            print("[LyricsFetcher] Decode error: \(error)")
            throw LyricsError.decodeError
        }
    }
}
