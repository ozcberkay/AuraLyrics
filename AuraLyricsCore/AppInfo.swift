import Foundation

/// Single source of truth for app identity strings.
///
/// The version is read from the bundle's `CFBundleShortVersionString`, which
/// `scripts/build_release_auralyrics.sh` writes into `Info.plist`. Plain `swift run`
/// builds have no Info.plist, so they report "dev".
public enum AppInfo {
    public static let repositoryURL = "https://github.com/ozcberkay/AuraLyrics"

    public static let version: String =
        Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "dev"

    /// lrclib.net asks API clients to identify themselves with a contactable
    /// User-Agent so its single maintainer can reach an app that misbehaves.
    public static let userAgent = "AuraLyrics/\(version) (+\(repositoryURL))"

    /// Attribution shown in the menu and README. Lyrics come from the lrclib.net
    /// community database; AuraLyrics stores no lyrics of its own.
    public static let lyricsAttribution = "Lyrics by LRCLIB"
    public static let lyricsSourceURL = "https://lrclib.net"
}
