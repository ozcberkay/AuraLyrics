import Foundation
import AuraLyricsCore
import Combine
import CryptoKit
import SwiftUI

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
    /// The in-flight lyrics fetch. Held so a new track can cancel the previous one:
    /// without this, two quick track changes race and the slower, older response
    /// lands last and shows the wrong song's lyrics.
    private var fetchTask: Task<Void, Never>?

    // Memory and disk caching (~/Library/Caches/AuraLyrics) live in AuraLyricsCore,
    // where they are behaviour-tested. Found lyrics are kept for good, "no lyrics"
    // answers for 24 hours, errors never.
    private let lyricsCache = LyricsCache(
        directory: FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)
            .first?.appendingPathComponent("AuraLyrics", isDirectory: true),
        fileName: LyricsManager.hashedFileName
    )

    /// Identifies one specific recording, not one song title. The key itself lives in
    /// AuraLyricsCore next to PlaybackState, where it is covered by behaviour tests.
    private func cacheKey(for state: PlaybackState) -> String {
        state.lyricsCacheKey
    }

    /// Hashing keeps the filename short and legal whatever characters a title
    /// contains: slashes, colons, and titles long enough to exceed the 255-byte
    /// filename limit on their own.
    private nonisolated static func hashedFileName(_ key: String) -> String {
        SHA256.hash(data: Data(key.utf8)).map { String(format: "%02x", $0) }.joined()
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

        // The last line that has started, skipping blank instrumental-gap entries.
        let matchingLine = lines.activeLine(at: currentPosition)

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

    /// Re-runs the fetch for the current track, used by the Retry button. It drops any
    /// cached answer for the track and always asks LRCLIB again, even when a "no lyrics"
    /// answer is remembered. A track change cancels it through the same
    /// fetchTask?.cancel() as any other fetch.
    func retry() {
        guard !lastState.track.isEmpty else { return }
        fetchLyrics(for: lastState, forceRefresh: true)
    }

    private func fetchLyrics(for playbackState: PlaybackState, forceRefresh: Bool = false) {
        // Cancel first, before the cache check: a cache hit returns synchronously
        // and an older in-flight fetch would still overwrite it when it lands.
        fetchTask?.cancel()

        // A cache hit (lyrics, or a recent "no lyrics") shows at once, no network.
        if !forceRefresh, let cached = lyricsCache.cachedState(for: playbackState) {
            show(cached)
            return
        }

        self.state = .loading   // was: isLoading = true; error = nil

        fetchTask = Task {
            // nil means the fetch was cancelled: leave the screen to whoever cancelled it.
            // The cache stores the result by its own rules and never stores errors.
            guard let result = await lyricsCache.load(
                playbackState,
                fetcher: fetcher,
                forceRefresh: forceRefresh
            ) else { return }

            guard !Task.isCancelled else { return }
            self.show(result)
        }
    }

    private func show(_ result: LyricsState) {
        self.state = result
        // Restart the timer if it stopped while we were waiting for lyrics to arrive.
        if case .loaded(let lines) = self.state, self.lastState.isPlaying && !lines.isEmpty {
            self.startTimerIfNeeded()
        }
    }
}
