import Foundation
import Combine
import AppKit

/// A service responsible for observing and querying Spotify.
class SpotifyService: ObservableObject {
    
    static let shared = SpotifyService()
    
    @Published var currentState: PlaybackState = .empty
    
    private var cancellables = Set<AnyCancellable>()
    private var appleScript: NSAppleScript?
    
    // Distributed Notification specifically for Spotify
    private let spotifyNotificationName = Notification.Name("com.spotify.client.PlaybackStateChanged")
    
    private init() {
        // Load the AppleScript
        if let scriptURL = Bundle.main.url(forResource: "SpotifyScript", withExtension: "scpt") {
            var error: NSDictionary?
            self.appleScript = NSAppleScript(contentsOf: scriptURL, error: &error)
            if let error = error {
                print("[SpotifyService] Error loading AppleScript: \(error)")
            }
        } else {
            // Fallback for development/testing
            let devPath = "/Users/berkayozcan/workspace/LyricsMaster/AuraLyrics/Resources/SpotifyScript.scpt"
            let devURL = URL(fileURLWithPath: devPath)
            var error: NSDictionary?
            self.appleScript = NSAppleScript(contentsOf: devURL, error: &error)
             if let error = error {
                print("[SpotifyService] Error loading AppleScript from dev path: \(error)")
            } else {
                print("[SpotifyService] Loaded AppleScript from dev path.")
            }
        }
        
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
        guard let userInfo = notification.userInfo else {
            fetchSpotifyState()
            return
        }
        
        // Try to parse the notification directly for instant feedback
        if let newState = parseNotificationUserInfo(userInfo) {
            DispatchQueue.main.async {
                if self.currentState != newState {
                    self.currentState = newState
                    // print("[SpotifyService] Fast Update: \(newState.track) @ \(newState.position)")
                }
            }
        } else {
            // Fallback if data is missing/obfuscated
            fetchSpotifyState()
        }
    }
    
    // Attempt to extract data purely from the Dictionary (no AppleScript)
    private func parseNotificationUserInfo(_ userInfo: [AnyHashable: Any]) -> PlaybackState? {
        // Keys are often: "Name", "Artist", "Album", "Duration", "Playback Position", "Player State"
        // Note: Duration and Position are usually Numbers (Int or Double) in milliseconds or seconds.
        
        guard let track = userInfo["Name"] as? String,
              let artist = userInfo["Artist"] as? String,
              let stateString = userInfo["Player State"] as? String
        else {
            return nil
        }
        
        let album = userInfo["Album"] as? String ?? ""
        let isPlaying = (stateString == "Playing") // Note: Capitalized "Playing" in userInfo usually
        
        // Parse Duration
        var duration: Double = {
            if let d = userInfo["Duration"] as? Double { return d }
            if let d = userInfo["Duration"] as? Int { return Double(d) }
            return 0
        }()
        
        // Parse Position
        var position: Double = {
            if let p = userInfo["Playback Position"] as? Double { return p }
            if let p = userInfo["Playback Position"] as? Int { return Double(p) }
            return 0
        }()
        
        // Normalize: Spotify sometimes sends milliseconds (e.g. 212000 for 212s)
        // Heuristic: If duration is > 3000 (50 mins is rare, but possible, but 3000s is 50m. 212000 is 58 hours).
        // Let's use a safe threshold. If > 10000 (approx 3 hours), it's definitely ms.
        // Standard pop song ~200s. 200,000 > 10000.
        if duration > 10000 {
            duration /= 1000
        }
        
        // Position should follow same logic or be checked independently
        if position > 10000 && position > duration {
             // If position is seemingly in ms (and larger than duration in seconds), fix it.
             position /= 1000
        } else if position > 10000 {
            // Just a long song or ms? If duration was ms, position likely was too.
            // If duration was already fixed to e.g. 212, and position is 50000, fix position.
            position /= 1000
        }
        
        return PlaybackState(
            track: track,
            artist: artist,
            album: album,
            isPlaying: isPlaying,
            position: position, // Will verify if this needs /1000
            duration: duration, // Will verify if this needs /1000
            timestamp: Date()
        )
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
        // Fire and forget, no need to wait for result typically, but executing on bg dict might be safer?
        // AppleScript must be run on main thread often for UI scripting, but this is simple IPC.
        NSAppleScript(source: source)?.executeAndReturnError(&error)
        
        // Optimistic update? Or just wait for 2s poll?
        // Let's force a fetch immediately after a small delay to update UI
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.1) {
            self.fetchSpotifyState()
        }
    }
    
    /// Executes the AppleScript to get the current state
    func fetchSpotifyState() {
        guard let script = appleScript else { return }
        
        var errorDict: NSDictionary?
        let descriptor = script.executeAndReturnError(&errorDict)
        
        if let error = errorDict {
            print("[SpotifyService] Script Execution Error: \(error)")
            return
        }
        
        guard let stringResult = descriptor.stringValue else {
            // If Spotify isn't running or returns non-string
            return
        }
        
        if stringResult == "NOT_RUNNING" {
            DispatchQueue.main.async {
                if self.currentState.isPlaying {
                    self.currentState = .empty
                }
            }
            return
        }
        
        if stringResult.starts(with: "ERROR") {
            print("[SpotifyService] AppleScript Error Signal: \(stringResult)")
            return
        }
        
        parseResult(stringResult)
    }
    
    private func parseResult(_ input: String) {
        // Format: Name|||Artist|||Album|||Duration(s)|||Position(s)|||State(playing/paused)
        let parts = input.components(separatedBy: "|||")
        
        guard parts.count >= 6 else {
            print("[SpotifyService] Parse Error: Unexpected format -> \(input)")
            return
        }
        
        let track = parts[0]
        let artist = parts[1]
        let album = parts[2]
        let durationString = parts[3].replacingOccurrences(of: ",", with: ".")
        let positionString = parts[4].replacingOccurrences(of: ",", with: ".")
        
        let duration = Double(durationString) ?? 0.0
        let position = Double(positionString) ?? 0.0
        let stateString = parts[5]
        
        let isPlaying = (stateString == "playing")
        
        let newState = PlaybackState(
            track: track,
            artist: artist,
            album: album,
            isPlaying: isPlaying,
            position: position,
            duration: duration,
            timestamp: Date()
        )
        
        DispatchQueue.main.async {
            // Determine if meaningful change occurred to reduce UI churn?
            // For now, we update on every event to keep sync (position might have jumped)
            if self.currentState != newState {
                self.currentState = newState
                print(newState) // Log for verification
            }
        }
    }
    
    deinit {
        DistributedNotificationCenter.default().removeObserver(self)
    }
}
