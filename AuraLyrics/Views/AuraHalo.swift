import AppKit
import SwiftUI

/// Turns the album artwork's average colour into a colour that still reads as *light*
/// when it sits behind white glyphs.
///
/// The raw average is often too dark or too washed out to glow: a moody cover can average
/// to near-black, a black-and-white cover to grey. Hue is the part that carries the album's
/// identity, so hue is preserved exactly and only saturation and brightness are floored.
/// A cover with almost no colour left has no meaningful hue to borrow, so it gets a neutral
/// white halo instead of an arbitrary one.
enum AuraHalo {
    /// Below this saturation the artwork is effectively greyscale and its hue is noise.
    private static let greyscaleThreshold: CGFloat = 0.08
    private static let minSaturation: CGFloat = 0.55
    private static let minBrightness: CGFloat = 0.85

    static func color(from average: NSColor?) -> Color? {
        guard let rgb = average?.usingColorSpace(.deviceRGB) else { return nil }

        var hue: CGFloat = 0, saturation: CGFloat = 0, brightness: CGFloat = 0
        rgb.getHue(&hue, saturation: &saturation, brightness: &brightness, alpha: nil)

        if saturation < greyscaleThreshold {
            return Color(nsColor: NSColor(white: 1.0, alpha: 1.0))
        }

        return Color(nsColor: NSColor(
            hue: hue,
            saturation: max(saturation, minSaturation),
            brightness: max(brightness, minBrightness),
            alpha: 1.0
        ))
    }
}
