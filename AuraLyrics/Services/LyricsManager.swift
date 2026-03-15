import Foundation
import Combine
import OSLog
import SwiftUI

// CACH-01: NSCache requires AnyObject values; struct LyricsLine needs a class wrapper
final class CachedLyricsLines: NSObject {
    let lines: [LyricsLine]
    init(_ lines: [LyricsLine]) { self.lines = lines }
}

@MainActor
class LyricsManager: ObservableObject {
    static let shared = LyricsManager()

    // ERRH-01/02: single typed state replaces lyrics+isLoading+error triple
    @Published var state: LyricsState = .idle

    var isSynced: Bool {
        if case .loaded(let lines) = state {
            return lines.first?.isSynced ?? false
        }
        return false
    }

    // Sync properties
    @Published var currentPosition: TimeInterval = 0
    @Published var activeLineID: UUID? = nil

    private let fetcher = LyricsFetcher()
    private var cancellables = Set<AnyCancellable>()
    private var currentTrackID: String? = nil
    private var lastState: PlaybackState = .empty
    private var timer: AnyCancellable?

    // CACH-01: In-memory NSCache with countLimit=50 for instant within-session track switches
    private let lyricsMemoryCache: NSCache<NSString, CachedLyricsLines> = {
        let c = NSCache<NSString, CachedLyricsLines>()
        c.countLimit = 50
        return c
    }()

    // CACH-02: Disk cache in ~/Library/Caches/AuraLyrics/
    private var cacheDirectory: URL? {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
            .first?.appendingPathComponent("AuraLyrics", isDirectory: true)
    }

    private func cacheFileURL(track: String, artist: String) -> URL? {
        let safeKey = "\(track)---\(artist)"
            .replacingOccurrences(of: "/", with: "_")
            .replacingOccurrences(of: ":", with: "_")
        return cacheDirectory?.appendingPathComponent("\(safeKey).json")
    }

    private func saveLyricsToDisk(_ lines: [LyricsLine], track: String, artist: String) {
        guard let fileURL = cacheFileURL(track: track, artist: artist),
              let dir = cacheDirectory else { return }
        Task.detached(priority: .background) {
            do {
                try FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
                let data = try JSONEncoder().encode(lines)
                try data.write(to: fileURL, options: .atomic)
            } catch {
                // Disk cache write failure is non-critical; in-memory cache still serves fast path
                Logger.lyricsManager.error(
                    "Disk cache write failed for track: \(track, privacy: .private), path: \(fileURL.path, privacy: .private) — \(error.localizedDescription, privacy: .public)"
                )
            }
        }
    }

    private func loadLyricsFromDisk(track: String, artist: String) -> [LyricsLine]? {
        guard let fileURL = cacheFileURL(track: track, artist: artist) else { return nil }
        do {
            let data = try Data(contentsOf: fileURL)
            return try JSONDecoder().decode([LyricsLine].self, from: data)
        } catch {
            return nil
        }
    }

    private init() {
        SpotifyService.shared.$currentState
            .sink { [weak self] state in
                self?.handleStateChange(state)
            }
            .store(in: &cancellables)
        // Timer starts only when needed — see handleStateChange
    }

    private func startTimerIfNeeded() {
        guard timer == nil else { return }
        timer = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updatePosition()
            }
    }

    private func stopTimer() {
        timer?.cancel()
        timer = nil
    }

    private func updatePosition() {
        guard lastState.isPlaying else { return }

        // Interpolation logic:
        // currentPosition = spotifyPosition + (now - spotifyTimestamp)
        let timePassedSinceLastUpdate = Date().timeIntervalSince(lastState.timestamp)
        self.currentPosition = lastState.position + timePassedSinceLastUpdate

        updateActiveLine()
    }

    private func updateActiveLine() {
        guard case .loaded(let lines) = state, isSynced else {
            if activeLineID != nil { self.activeLineID = nil }
            return
        }

        // Find the line where startTime <= currentPosition
        let matchingLine = lines.last { $0.startTime <= currentPosition }

        if activeLineID != matchingLine?.id {
            withAnimation(.spring(response: 0.4, dampingFraction: 0.7)) {
                self.activeLineID = matchingLine?.id
            }
        }
    }

    private func handleStateChange(_ state: PlaybackState) {
        self.lastState = state
        let trackID = "\(state.track)-\(state.artist)"

        // Only fetch if track has changed and it's not empty
        if trackID != currentTrackID && !state.track.isEmpty {
            currentTrackID = trackID
            fetchLyrics(for: state)
        } else if state.track.isEmpty {
            self.state = .idle   // was: lyrics = []; activeLineID = nil
            currentTrackID = nil
            activeLineID = nil
        }

        // Immediately update position when state changes (e.g. seek)
        self.currentPosition = state.position
        updateActiveLine()

        // TIMR-02: pause timer when not playing or no lyrics loaded
        if case .loaded(let lines) = self.state, state.isPlaying && !lines.isEmpty {
            startTimerIfNeeded()
        } else {
            stopTimer()
        }
    }

    private func fetchLyrics(for playbackState: PlaybackState) {
        // CACH-01: Check in-memory cache first — instant hit for same-session track revisits
        let cacheKey = "\(playbackState.track)---\(playbackState.artist)" as NSString
        if let cached = lyricsMemoryCache.object(forKey: cacheKey) {
            self.state = .loaded(cached.lines)
            if case .loaded(let lines) = self.state, self.lastState.isPlaying && !lines.isEmpty {
                self.startTimerIfNeeded()
            }
            return
        }

        self.state = .loading   // was: isLoading = true; error = nil

        Task {
            // CACH-02: Check disk cache before going to network — survives app relaunches
            if let diskLines = self.loadLyricsFromDisk(track: playbackState.track, artist: playbackState.artist) {
                self.lyricsMemoryCache.setObject(CachedLyricsLines(diskLines), forKey: cacheKey)
                self.state = .loaded(diskLines)
                if case .loaded(let lines) = self.state, self.lastState.isPlaying && !lines.isEmpty {
                    self.startTimerIfNeeded()
                }
                return
            }

            do {
                let fetchedLyrics = try await fetcher.fetchLyrics(
                    track: playbackState.track,
                    artist: playbackState.artist,
                    album: playbackState.album,
                    duration: playbackState.duration
                )
                self.state = .loaded(fetchedLyrics)   // was: self.lyrics = fetchedLyrics; self.isLoading = false

                // CACH-01/02: Populate both cache layers after successful network fetch
                self.lyricsMemoryCache.setObject(CachedLyricsLines(fetchedLyrics), forKey: cacheKey)
                self.saveLyricsToDisk(fetchedLyrics, track: playbackState.track, artist: playbackState.artist)

                // TIMR-02: restart timer if we were waiting for lyrics to arrive
                if case .loaded(let lines) = self.state, self.lastState.isPlaying && !lines.isEmpty {
                    self.startTimerIfNeeded()
                }
            } catch {
                // ERRH-01/02: typed error dispatch → distinct LyricsState cases
                switch error as? LyricsError {
                case .notFound:
                    self.state = .notFound(track: playbackState.track, artist: playbackState.artist)
                case .instrumental:
                    self.state = .instrumental(track: playbackState.track, artist: playbackState.artist)
                default:
                    self.state = .error("Failed to fetch lyrics")  // network/decode errors
                }
            }
        }
    }
}

// LOGG-01: os.Logger extension for LyricsManager — private scope, same pattern as SpotifyService
private extension Logger {
    static let subsystem = Bundle.main.bundleIdentifier ?? "com.auralyrics"
    static let lyricsManager = Logger(subsystem: subsystem, category: "LyricsManager")
}
