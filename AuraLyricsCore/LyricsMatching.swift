import Foundation

/// Pure helpers for picking LRCLIB search results, cleaning titles and splitting artists.
enum LyricsMatching {
    static let maxDurationDifference = 3.0
    static let titleThreshold = 0.8
    static let artistFullThreshold = 0.6
    static let artistPartThreshold = 0.8

    // Same character set LRCLIB's server strips when it normalizes search input.
    private static let spaceCharacters = Set("`~!@#$%^&*()_|+-=?;:\",.<>{}[]\\/\u{0}\n")

    /// Mirrors LRCLIB's server-side input preparation so client and server compare alike.
    static func normalize(_ s: String) -> String {
        let folded = s.precomposedStringWithCompatibilityMapping
            .folding(options: [.caseInsensitive, .diacriticInsensitive], locale: nil)
            .lowercased()
            .replacingOccurrences(of: "ı", with: "i")
        var out = ""
        for ch in folded {
            if ch == "'" || ch == "\u{2019}" { continue }
            out.append(spaceCharacters.contains(ch) ? " " : ch)
        }
        return out.split(whereSeparator: { $0.isWhitespace }).joined(separator: " ")
    }

    /// Sørensen-Dice on character bigrams of the normalized strings; 1 when equal, 0 when either is empty.
    static func similarity(_ a: String, _ b: String) -> Double {
        let x = normalize(a), y = normalize(b)
        if x.isEmpty || y.isEmpty { return 0 }
        if x == y { return 1 }
        func bigrams(_ s: String) -> [String: Int] {
            let chars = Array(s.filter { $0 != " " })
            var counts: [String: Int] = [:]
            if chars.count < 2 { return counts }
            for i in 0..<(chars.count - 1) { counts[String(chars[i...i + 1]), default: 0] += 1 }
            return counts
        }
        let bx = bigrams(x), by = bigrams(y)
        let total = bx.values.reduce(0, +) + by.values.reduce(0, +)
        if total == 0 { return 0 }
        let shared = bx.reduce(0) { $0 + min($1.value, by[$1.key] ?? 0) }
        return 2.0 * Double(shared) / Double(total)
    }

    private static let suffixVariant =
        #"\b(remaster\w*|live|radio edit|single version|mono|stereo|mix|edit|version|demo|acoustic|bonus track)\b"#
    private static let groupVariant =
        #"\b(remaster\w*|live|radio edit|single version|mono|stereo|mix)\b"#
    private static let groupFeature = #"^(feat\.?|ft\.?|with)(\s|$)"#
    private static let group = try! NSRegularExpression(pattern: #"[(\[][^)\]]*[)\]]"#)

    /// Strips release-variant noise (remaster, live, feat. groups) so a second search can match the base title.
    /// Returns nil when nothing was removed, so the caller can skip a duplicate request.
    static func cleanTitle(_ title: String) -> String? {
        var current = title.trimmingCharacters(in: .whitespaces)
        var changed = false
        while true {
            if let next = removingFirstGroup(current) ?? removingVariantSuffix(current) {
                current = next.trimmingCharacters(in: .whitespaces)
                changed = true
            } else {
                break
            }
        }
        return changed && !current.isEmpty ? current : nil
    }

    private static func removingFirstGroup(_ s: String) -> String? {
        let ns = s as NSString
        for m in group.matches(in: s, range: NSRange(location: 0, length: ns.length)) {
            let inner = ns.substring(with: NSRange(location: m.range.location + 1, length: m.range.length - 2))
                .trimmingCharacters(in: .whitespaces)
            if inner.range(of: groupFeature, options: [.regularExpression, .caseInsensitive]) != nil
                || inner.range(of: groupVariant, options: [.regularExpression, .caseInsensitive]) != nil {
                return ns.replacingCharacters(in: m.range, with: "")
                    .split(separator: " ", omittingEmptySubsequences: true).joined(separator: " ")
            }
        }
        return nil
    }

    private static func removingVariantSuffix(_ s: String) -> String? {
        guard let dash = s.range(of: " - ", options: .backwards) else { return nil }
        let tail = s[dash.upperBound...]
        guard tail.range(of: suffixVariant, options: [.regularExpression, .caseInsensitive]) != nil else { return nil }
        return String(s[..<dash.lowerBound])
    }

    /// Splits a joined artist string ("Jay-Z, Kanye West") into individual artists.
    static func splitArtists(_ artist: String) -> [String] {
        artist
            .replacingOccurrences(
                of: #"(, | & | feat\. | ft\. | featuring | x )"#, with: "\u{1}",
                options: [.regularExpression, .caseInsensitive])
            .split(separator: "\u{1}", omittingEmptySubsequences: true)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .filter { !$0.isEmpty }
    }

    /// Picks the best search result for a track: close duration, similar title and artist,
    /// then synced lyrics over plain over instrumental, nearest duration first.
    static func pickBest(_ candidates: [LRCLibResponse], title: String, artist: String, duration: Double) -> LRCLibResponse? {
        let wantedArtists = splitArtists(artist)
        let cleanedTitle = cleanTitle(title) ?? title

        func rank(_ c: LRCLibResponse) -> Int {
            if !(c.syncedLyrics ?? "").isEmpty { return 0 }
            if !(c.plainLyrics ?? "").isEmpty { return 1 }
            return 2
        }
        func titleOK(_ c: LRCLibResponse) -> Bool {
            let name = c.trackName ?? ""
            return similarity(name, title) >= titleThreshold
                || similarity(cleanTitle(name) ?? name, cleanedTitle) >= titleThreshold
        }
        func artistOK(_ c: LRCLibResponse) -> Bool {
            let name = c.artistName ?? ""
            if similarity(name, artist) >= artistFullThreshold { return true }
            for a in wantedArtists {
                for b in splitArtists(name) where similarity(a, b) >= artistPartThreshold { return true }
            }
            let x = normalize(artist), y = normalize(name)
            let (short, long) = x.count <= y.count ? (x, y) : (y, x)
            // The shorter name must be a whole word run of the longer one, not a fragment of a word.
            return short.count >= 3 && (" " + long + " ").contains(" " + short + " ")
        }

        return candidates
            .compactMap { c -> (LRCLibResponse, Int, Double)? in
                guard let d = c.duration, abs(d - duration) <= maxDurationDifference else { return nil }
                let hasLyrics = !(c.syncedLyrics ?? "").isEmpty || !(c.plainLyrics ?? "").isEmpty
                guard hasLyrics || c.instrumental == true, titleOK(c), artistOK(c) else { return nil }
                return (c, rank(c), abs(d - duration))
            }
            .min { ($0.1, $0.2) < ($1.1, $1.2) }?.0
    }
}
