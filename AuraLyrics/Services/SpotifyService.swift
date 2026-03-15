import Foundation
import Combine
import AppKit
import OSLog

/// A service responsible for observing and querying Spotify.
@MainActor
class SpotifyService: ObservableObject {

    static let shared = SpotifyService()

    @Published var currentState: PlaybackState = .empty
    @Published var artworkImage: NSImage? = nil

    // CACH-03: in-memory artwork cache — NSImage is NSObject, no wrapper needed
    private let artworkCache: NSCache<NSString, NSImage> = {
        let c = NSCache<NSString, NSImage>()
        c.countLimit = 20   // CACH-03
        return c
    }()

    // CACH-04: color extraction result — computed once per artwork URL, nil on track change
    @Published var artworkAverageColor: NSColor? = nil

    // ERRH-03: AppleScript health monitor
    private var consecutiveAppleScriptFailures = 0
    private let appleScriptFailureThreshold = 5
    @Published var isDegraded: Bool = false

    private var cancellables = Set<AnyCancellable>()
    private var pollTimer: AnyCancellable?
    // PERF-01: track current interval so startPolling(interval:) can no-op on same-interval calls
    private var currentPollInterval: TimeInterval = 2.0

    // NETW-03: stored task reference — cancelled before starting a new fetch
    private var artworkTask: Task<Void, Never>?

    // ERRH-04: allowlist of trusted Spotify CDN hostnames for artwork URLs
    private static let trustedArtworkHosts: Set<String> = ["i.scdn.co", "mosaic.scdn.co"]

    // ERRH-04: validate artwork URL — must be HTTPS and from a trusted host
    private func isValidArtworkURL(_ urlString: String) -> Bool {
        guard let url = URL(string: urlString),
              url.scheme == "https",
              let host = url.host,
              Self.trustedArtworkHosts.contains(host) else {
            Logger.spotifyService.debug(
                "Artwork URL rejected: \(urlString, privacy: .private)"
            )
            return false
        }
        return true
    }

    // THRD-02: All AppleScript execution runs on this serial queue — never main thread
    // Serial (not concurrent) by default — NSAppleScript is not thread-safe
    private let appleScriptQueue = DispatchQueue(
        label: "com.auralyrics.applescript",
        qos: .userInitiated
    )

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

    // THRD-03: Compiled once on first use. lazy var init runs on @MainActor (XProtect-safe).
    // Subsequent executeAndReturnError calls skip recompilation.
    private lazy var pollScript: NSAppleScript? = {
        let script = NSAppleScript(source: pollScriptSource)
        var compileError: NSDictionary?
        // Explicit compile — surfacing errors early rather than silently at runtime
        script?.compileAndReturnError(&compileError)
        if compileError != nil {
            Logger.spotifyService.fault("Failed to compile AppleScript: \(String(describing: compileError), privacy: .public)")
            return nil
        }
        return script
    }()

    private init() {
        setupObservers()
        startPolling(interval: 2.0)
        // Initial fetch
        fetchSpotifyState()
    }

    private func setupObservers() {
        Logger.spotifyService.debug("Setting up observer: \(self.spotifyNotificationName.rawValue, privacy: .public)")
        DistributedNotificationCenter.default()
            .publisher(for: spotifyNotificationName)
            .sink { [weak self] _ in self?.fetchSpotifyState() }
            .store(in: &cancellables)
    }

    // PERF-01: adaptive polling — 2.0s playing, 5.0s paused, 10.0s not running
    private func startPolling(interval: TimeInterval) {
        // No-op if timer is already running at the same interval
        guard pollTimer == nil || currentPollInterval != interval else { return }
        pollTimer?.cancel()
        pollTimer = nil
        currentPollInterval = interval
        pollTimer = Timer.publish(every: interval, on: .main, in: .common)
            .autoconnect()
            .sink { [weak self] _ in
                self?.fetchSpotifyState()
            }
    }

    private func stopPolling() {
        pollTimer?.cancel()
        pollTimer = nil
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

        appleScriptQueue.async { [weak self] in
            let commandScript = NSAppleScript(source: source)
            var error: NSDictionary?
            commandScript?.executeAndReturnError(&error)

            // Fetch updated state after a brief delay for Spotify to process the command
            Task { @MainActor [weak self] in
                try? await Task.sleep(nanoseconds: 100_000_000)  // 0.1s
                self?.fetchSpotifyState()
            }
        }
    }

    /// Executes the AppleScript to get the current state
    func fetchSpotifyState() {
        // THRD-03: reuse compiled instance — lazy init runs on @MainActor on first call
        guard let script = pollScript else { return }

        // THRD-02: dispatch execution to serial background queue — never blocks main thread
        appleScriptQueue.async { [weak self] in
            var errorDict: NSDictionary?
            let descriptor = script.executeAndReturnError(&errorDict)

            // ERRH-03: accumulate consecutive failures; degrade after threshold
            if errorDict != nil || descriptor.stringValue == nil {
                self?.consecutiveAppleScriptFailures += 1
                if let self = self,
                   self.consecutiveAppleScriptFailures >= self.appleScriptFailureThreshold {
                    Task { @MainActor [weak self] in
                        self?.isDegraded = true
                    }
                }
                return
            }
            self?.consecutiveAppleScriptFailures = 0  // reset on success
            let stringResult = descriptor.stringValue!  // safe: checked above

            // Dispatch result handling back to main actor
            Task { @MainActor [weak self] in
                self?.handleAppleScriptResult(stringResult)
            }
        }
    }

    // @MainActor is inherited from the class — no annotation needed on the method
    private func handleAppleScriptResult(_ result: String) {
        if result == "NOT_RUNNING" {
            // PERF-01: slow-poll at 10s instead of stopping entirely — reduces CPU while Spotify is absent
            startPolling(interval: 10.0)
            if currentState != .notRunning {
                currentState = .notRunning
                artworkImage = nil
            }
            return
        }

        if result.starts(with: "ERROR") { return }

        // TIMR-03: resume polling if it was paused; parseResult will immediately adjust to 5.0 if paused
        startPolling(interval: 2.0)

        parseResult(result)
    }

    private func parseResult(_ input: String) {
        // Format: Name|||Artist|||Album|||Duration(s)|||Position(s)|||State(playing/paused)|||ArtworkUrl

        let parts = input.components(separatedBy: "|||")

        guard parts.count >= 7 else {
            Logger.spotifyService.error("Parse error: unexpected AppleScript result format")
            return
        }

        let artworkUrl = parts[6]

        // Check if artwork URL changed, then fetch (ERRH-04: validate before URLSession)
        if artworkUrl != currentState.artworkUrl && isValidArtworkURL(artworkUrl) {
            // CACH-04: clear stale color before fetching new artwork
            self.artworkAverageColor = nil
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

        // PERF-01: adjust poll interval before publishing state — 2s when playing, 5s when paused
        startPolling(interval: isPlaying ? 2.0 : 5.0)

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

        if self.currentState != newState {
            self.currentState = newState
        }
    }

    private func fetchArtwork(url: String) {
        // NETW-03: cancel any in-flight fetch before starting a new one (prevents task stacking)
        artworkTask?.cancel()
        artworkTask = nil

        // CACH-03: capture key before any async context — Task closure captures a local String copy
        let urlKey = url as NSString

        // CACH-03: serve from cache if available — no URLSession request needed
        if let cachedImage = artworkCache.object(forKey: urlKey) {
            self.artworkImage = cachedImage
            Task.detached(priority: .utility) { [weak self] in
                let color = cachedImage.averageColor
                await MainActor.run { [weak self] in self?.artworkAverageColor = color }
            }
            return
        }

        guard let validUrl = URL(string: url) else { return }

        artworkTask = Task {
            do {
                var request = URLRequest(url: validUrl)
                request.timeoutInterval = 10  // NETW-01: 10-second timeout (Phase 2 adds retry)

                let (data, response) = try await URLSession.shared.data(for: request)

                // NETW-03: check cancellation after network round-trip completes
                guard !Task.isCancelled else { return }

                guard let httpResponse = response as? HTTPURLResponse,
                      httpResponse.statusCode == 200 else { return }

                if let image = NSImage(data: data) {
                    // @MainActor inherited from SpotifyService — direct assignment is safe
                    self.artworkCache.setObject(image, forKey: urlKey)
                    self.artworkImage = image
                    // CACH-04: extract color off @MainActor — CGContext resize + pixel read
                    Task.detached(priority: .utility) { [weak self] in
                        let color = image.averageColor
                        await MainActor.run { [weak self] in self?.artworkAverageColor = color }
                    }
                }
            } catch {
                Logger.spotifyService.debug("Artwork fetch error: \(error.localizedDescription, privacy: .public)")
            }
        }
    }

}

// LOGG-01/02: os.Logger extension — private scope avoids polluting global Logger namespace
private extension Logger {
    static let subsystem = Bundle.main.bundleIdentifier ?? "com.auralyrics"
    static let spotifyService = Logger(subsystem: subsystem, category: "SpotifyService")
}
