import Foundation

/// Single source of truth for app identity strings.
///
/// The version is read from the bundle's `CFBundleShortVersionString`, the build number
/// from `CFBundleVersion` and the git short commit from `AuraLyricsGitCommit`, all of
/// which `scripts/build_release_auralyrics.sh` writes into `Info.plist`. Plain
/// `swift run` builds have no Info.plist, so they report "dev".
public enum AppInfo {
    public static let repositoryURL = "https://github.com/ozcberkay/AuraLyrics"

    /// Custom Info.plist key holding the git short commit of the release build.
    public static let gitCommitKey = "AuraLyricsGitCommit"

    /// Returns a non-empty string for `key`, or nil when missing, empty or not a String.
    private static func string(_ key: String, in info: [String: Any]?) -> String? {
        guard let value = info?[key] as? String, !value.isEmpty else { return nil }
        return value
    }

    private static let devVersion = "dev"

    /// Short version, or "dev" when the bundle has none.
    public static func shortVersion(infoDictionary: [String: Any]?) -> String {
        string("CFBundleShortVersionString", in: infoDictionary) ?? devVersion
    }

    /// Human readable version for the About panel: "1.2.0", "1.2.0 (142)",
    /// "1.2.0 (abc1234)" or "1.2.0 (142, abc1234)". The build number is hidden
    /// when it equals the short version.
    public static func versionDescription(infoDictionary: [String: Any]?) -> String {
        guard let short = string("CFBundleShortVersionString", in: infoDictionary) else { return devVersion }
        var details: [String] = []
        if let build = string("CFBundleVersion", in: infoDictionary), build != short {
            details.append(build)
        }
        if let commit = string(gitCommitKey, in: infoDictionary) {
            details.append(commit)
        }
        return details.isEmpty ? short : "\(short) (\(details.joined(separator: ", ")))"
    }

    public static let version: String = shortVersion(infoDictionary: Bundle.main.infoDictionary)

    public static let displayVersion: String =
        versionDescription(infoDictionary: Bundle.main.infoDictionary)

    /// lrclib.net asks API clients to identify themselves with a contactable
    /// User-Agent so its single maintainer can reach an app that misbehaves.
    public static let userAgent = "AuraLyrics/\(version) (+\(repositoryURL))"

    /// Attribution shown in the menu and README. Lyrics come from the lrclib.net
    /// community database; AuraLyrics stores no lyrics of its own.
    public static let lyricsAttribution = "Lyrics by LRCLIB"
    public static let lyricsSourceURL = "https://lrclib.net"
}
