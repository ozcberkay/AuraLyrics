import Foundation
import Combine
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
        self.state = .loading   // was: isLoading = true; error = nil

        Task {
            do {
                let fetchedLyrics = try await fetcher.fetchLyrics(
                    track: playbackState.track,
                    artist: playbackState.artist,
                    album: playbackState.album,
                    duration: playbackState.duration
                )
                self.state = .loaded(fetchedLyrics)   // was: self.lyrics = fetchedLyrics; self.isLoading = false

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
