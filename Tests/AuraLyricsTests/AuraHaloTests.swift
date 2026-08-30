import XCTest

final class AuraHaloTests: XCTestCase {

    private func source(_ file: String) throws -> String {
        let url = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()   // AuraLyricsTests/
            .deletingLastPathComponent()   // Tests/
            .deletingLastPathComponent()   // project root
            .appendingPathComponent(file)
        return try String(contentsOf: url, encoding: .utf8)
    }

    /// Aura mode sits over the user's work. The album colour must reach the glyphs, never a
    /// background wash, or the mode stops being something you can ignore while working.
    func testAuraViewHasNoBackgroundFill() throws {
        let s = try source("AuraLyrics/Views/AuraView.swift")
        XCTAssertTrue(
            s.contains("Color.clear"),
            "AuraView must keep a transparent background"
        )
        XCTAssertFalse(
            s.contains("AdaptiveBackgroundView"),
            "AuraView must not gain a background wash — the halo goes on the text instead"
        )
    }

    func testActiveLineCarriesAlbumColouredHalo() throws {
        let s = try source("AuraLyrics/Views/AuraView.swift")
        XCTAssertTrue(s.contains("AuraHalo.color(from: spotifyService.artworkAverageColor)"),
                      "The halo colour must come from the artwork average via AuraHalo")
        XCTAssertTrue(s.contains("HaloLine("),
                      "Aura lines must render through HaloLine")
        XCTAssertTrue(s.contains("value: spotifyService.artworkAverageColor"),
                      "The halo must cross-fade on track change rather than cutting")
    }

    /// Chaining `.shadow(halo)` after the black legibility shadow makes SwiftUI rasterise the
    /// text with that shadow and cast every later shadow from the composite, which draws a
    /// visible dark contour around the whole line. The halo has to be its own blurred layer.
    func testHaloIsALayerNotAChainedShadow() throws {
        let s = try source("AuraLyrics/Views/AuraView.swift")
        XCTAssertFalse(s.contains(".shadow(color: halo"),
                       "Halo must not be a chained .shadow — that produces a dark contour artifact")
        let halo = try source("AuraLyrics/Views/AuraView.swift")
        XCTAssertTrue(halo.contains("struct HaloLine") && halo.contains("ZStack"),
                      "HaloLine must draw a blurred colour copy behind the crisp text")
    }

    /// The first thing shown on launch is the track title, before any lyric line is active.
    /// It carries the halo too, otherwise the feature looks broken until the chorus.
    func testTrackTitleStatesAlsoCarryTheHalo() throws {
        let s = try source("AuraLyrics/Views/AuraView.swift")
        let occurrences = s.components(separatedBy: "currentSize.trackTitleFontSize").count - 1
        let haloed = s.components(separatedBy: "font: .system(size: currentSize.trackTitleFontSize").count - 1
        XCTAssertEqual(haloed, occurrences,
                       "Every track-title state (intro, idle, notFound, instrumental) must use HaloLine")
    }

    /// A moody cover averages to near-black and a black-and-white cover to grey. Neither can
    /// glow, so hue is kept and saturation/brightness are floored — and a cover with no colour
    /// left gets a neutral halo instead of an arbitrary hue.
    func testHaloFloorsSaturationAndBrightness() throws {
        let s = try source("AuraLyrics/Models/../Views/AuraHalo.swift")
        XCTAssertTrue(s.contains("minSaturation") && s.contains("minBrightness"),
                      "AuraHalo must floor saturation and brightness so dark covers still glow")
        XCTAssertTrue(s.contains("greyscaleThreshold"),
                      "AuraHalo must fall back to a neutral halo for greyscale artwork")
        XCTAssertTrue(s.contains("getHue(&hue"),
                      "AuraHalo must preserve the artwork hue rather than inventing one")
    }

    /// A borderless panel takes its shadow from the alpha silhouette of its content. With
    /// transparent content that traces a dark contour around every glyph — and around the
    /// blurred halo. The Aura panel must therefore opt out; the lyrics card still wants one.
    func testAuraPanelDrawsNoWindowShadow() throws {
        let panel = try source("AuraLyrics/Services/FloatingPanel.swift")
        XCTAssertTrue(panel.contains("drawsShadow: Bool = true") && panel.contains("self.hasShadow = drawsShadow"),
                      "FloatingPanel must let a panel opt out of the window shadow")

        let wm = try source("AuraLyrics/Services/WindowManager.swift")
        guard let auraRange = wm.range(of: "let auraP = FloatingPanel(") else {
            return XCTFail("Aura panel construction not found")
        }
        let auraInit = String(wm[auraRange.lowerBound..<(wm.range(of: ")", range: auraRange.upperBound..<wm.endIndex)?.upperBound ?? wm.endIndex)])
        XCTAssertTrue(wm[auraRange.lowerBound...].prefix(600).contains("drawsShadow: false"),
                      "The Aura panel must be created with drawsShadow: false")
        _ = auraInit
    }
}
