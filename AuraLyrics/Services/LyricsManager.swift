import Foundation
import Combine
import SwiftUI

class LyricsManager: ObservableObject {
    static let shared = LyricsManager()
    
    @Published var lyrics: [LyricsLine] = []
    @Published var isLoading: Bool = false
    @Published var error: String? = nil
    
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
            .receive(on: DispatchQueue.main)
            .sink { [weak self] state in
                self?.handleStateChange(state)
            }
            .store(in: &cancellables)
        
        startTimer()
    }
    
    private func startTimer() {
        timer = Timer.publish(every: 0.1, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.updatePosition()
            }
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
        guard !lyrics.isEmpty else { return }
        
        // Find the line where startTime <= currentPosition
        // Since lyrics are sorted, we can find the last one that matches
        let matchingLine = lyrics.last { $0.startTime <= currentPosition }
        
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
            lyrics = []
            currentTrackID = nil
            activeLineID = nil
        }
        
        // Immediately update position when state changes (e.g. seek)
        self.currentPosition = state.position
        updateActiveLine()
    }
    
    private func fetchLyrics(for state: PlaybackState) {
        isLoading = true
        error = nil
        
        Task {
            do {
                let fetchedLyrics = try await fetcher.fetchLyrics(
                    track: state.track,
                    artist: state.artist,
                    album: state.album,
                    duration: state.duration
                )
                
                await MainActor.run {
                    self.lyrics = fetchedLyrics
                    self.isLoading = false
                    print("[LyricsManager] Fetched \(fetchedLyrics.count) lines for \(state.track)")
                }
            } catch {
                await MainActor.run {
                    self.isLoading = false
                    if let lyricsError = error as? LyricsError, lyricsError == .notFound {
                        self.error = "Lyrics not found"
                    } else {
                        self.error = "Failed to fetch lyrics"
                    }
                    self.lyrics = []
                    print("[LyricsManager] Error fetching lyrics: \(error)")
                }
            }
        }
    }
}
