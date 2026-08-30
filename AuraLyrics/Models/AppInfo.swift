import Foundation

/// Single source of truth for app identity strings.
///
/// The version is read from the bundle's `CFBundleShortVersionString`, which
/// `scripts/build_release_auralyrics.sh` writes into `Info.plist`. Plain `swift run`
/// builds have no Info.plist, so they report "dev".
enum AppInfo {
    static let repositoryURL = "https://github.com/ozcberkay/AuraLyrics"

    static let version: String =
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"

    /// lrclib.net asks API clients to identify themselves with a contactable
    /// User-Agent so its single maintainer can reach an app that misbehaves.
    static let userAgent = "AuraLyrics/\(version) (+\(repositoryURL))"

    /// Attribution shown in the menu and README. Lyrics come from the lrclib.net
    /// community database; AuraLyrics stores no lyrics of its own.
    static let lyricsAttribution = "Lyrics by LRCLIB"
    static let lyricsSourceURL = "https://lrclib.net"
}
