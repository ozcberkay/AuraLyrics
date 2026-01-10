import Foundation
import Combine
import AppKit

/// A service responsible for observing and querying Spotify.
class SpotifyService: ObservableObject {
    
    static let shared = SpotifyService()
    
    @Published var currentState: PlaybackState = .empty
    @Published var artworkImage: NSImage? = nil 
    
    private var cancellables = Set<AnyCancellable>()
    
    // Distributed Notification specifically for Spotify
    private let spotifyNotificationName = Notification.Name("com.spotify.client.PlaybackStateChanged")
    
    // Embedded AppleScript to ensure it works without external resources
    // Fetches: Name, Artist, Album, Duration, Position, State, ArtworkURL
    private let pollScriptSource: String = """
    tell application "Spotify"
        if it is running then
            try
                set t to current track
                set tName to name of t
                set tArtist to artist of t
                set tAlbum to album of t
                set tDuration to duration of t
                set tArtwork to artwork url of t
                set pState to player state
                set pPosition to player position
                
                return tName & "|||" & tArtist & "|||" & tAlbum & "|||" & tDuration & "|||" & pPosition & "|||" & pState & "|||" & tArtwork
            on error
                return "ERROR"
            end try
        else
            return "NOT_RUNNING"
        end if
    end tell
    """
    
    private init() {
        setupObservers()
        startPolling()
        // Initial fetch
        fetchSpotifyState()
    }
    
    private func setupObservers() {
        print("[SpotifyService] Setting up observer for: \(spotifyNotificationName.rawValue)")
        DistributedNotificationCenter.default().addObserver(
            self,
            selector: #selector(playbackStateChanged),
            name: spotifyNotificationName,
            object: nil
        )
    }
    
    private func startPolling() {
        // Poll every 2 seconds to catch seeking/drifting that doesn't trigger a notification
        Timer.scheduledTimer(withTimeInterval: 2.0, repeats: true) { [weak self] _ in
            self?.fetchSpotifyState()
        }
    }
    
    @objc private func playbackStateChanged(_ notification: Notification) {
        // Always fetch full state to ensure we get artwork and correct sync
        fetchSpotifyState()
    }
    
    func nextTrack() {
        runSpotifyCommand("next track")
    }
    
    func previousTrack() {
        runSpotifyCommand("previous track")
    }
    
    func playPause() {
        runSpotifyCommand("playpause")
    }
    
    private func runSpotifyCommand(_ command: String) {
        let source = "tell application \"Spotify\" to \(command)"
        var error: NSDictionary?
        NSAppleScript(source: source)?.executeAndReturnError(&error)
        
        // Optimistic update? Or just wait for 2s poll?
        // Let's force a fetch immediately after a small delay to update UI
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.fetchSpotifyState()
        }
    }
    
    /// Executes the AppleScript to get the current state
    func fetchSpotifyState() {
        var errorDict: NSDictionary?
        // Use the embedded source
        guard let script = NSAppleScript(source: pollScriptSource) else {
            print("[SpotifyService] Failed to init AppleScript")
            return
        }
        
        let descriptor = script.executeAndReturnError(&errorDict)
        
        if errorDict != nil {
            return
        }
        
        guard let stringResult = descriptor.stringValue else {
            return
        }
        
        if stringResult == "NOT_RUNNING" {
            DispatchQueue.main.async {
                if self.currentState != .notRunning {
                    self.currentState = .notRunning
                    self.artworkImage = nil
                }
            }
            return
        }
        
        if stringResult.starts(with: "ERROR") {
            return
        }
        
        parseResult(stringResult)
    }
    
    private func parseResult(_ input: String) {
        // Format: Name|||Artist|||Album|||Duration(s)|||Position(s)|||State(playing/paused)|||ArtworkUrl
        
        let parts = input.components(separatedBy: "|||")
        
        guard parts.count >= 7 else {
            print("[SpotifyService] Parse Error: Unexpected format -> \(input)")
            return
        }
        
        let artworkUrl = parts[6]
        
        // Check if artwork URL changed, then fetch
        if artworkUrl != currentState.artworkUrl && !artworkUrl.isEmpty {
           fetchArtwork(url: artworkUrl)
        }
        
        let track = parts[0]
        let artist = parts[1]
        let album = parts[2]
        let durationString = parts[3].replacingOccurrences(of: ",", with: ".")
        let positionString = parts[4].replacingOccurrences(of: ",", with: ".")
        
        var duration = Double(durationString) ?? 0.0
        var position = Double(positionString) ?? 0.0
        
        // Normalize milliseconds to seconds
        if duration > 10000 {
            duration /= 1000
        }
        if position > 10000 && position > duration {
             position /= 1000
        } else if position > duration * 1000 {
             position /= 1000
        }
        
        let stateString = parts[5]
        
        let isPlaying = (stateString == "playing")
        
        let newState = PlaybackState(
            track: track,
            artist: artist,
            album: album,
            isPlaying: isPlaying,
            position: position,
            duration: duration,
            artworkUrl: artworkUrl,
            isSpotifyRunning: true, // If we got here, it's running
            timestamp: Date()
        )
        
        DispatchQueue.main.async {
            if self.currentState != newState {
                self.currentState = newState
            }
        }
    }
    
    private func fetchArtwork(url: String) {
        guard let validUrl = URL(string: url) else { return }
        
        DispatchQueue.global(qos: .background).async {
            if let data = try? Data(contentsOf: validUrl), let image = NSImage(data: data) {
                DispatchQueue.main.async {
                    self.artworkImage = image
                }
            }
        }
    }
    
    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
    }
}
