import SwiftUI

struct AuraView: View {
    @ObservedObject var lyricsManager = LyricsManager.shared
    @ObservedObject var spotifyService = SpotifyService.shared
    @ObservedObject var sizeManager = AuraSizeManager.shared

    // Configure appearance (colors and scales remain constant)
    private let activeColor = Color.white
    private let inactiveColor = Color.white.opacity(0.4)
    private let activeScale: CGFloat = 1.0
    private let inactiveScale: CGFloat = 0.8

    // Dynamic size properties from AuraSizeManager
    private var currentSize: AuraSize { sizeManager.currentSize }

    /// Album-coloured halo for the active line. Aura mode sits over whatever the user is
    /// working on, so the colour is attached to the glyphs rather than washed across a
    /// background: it adds identity without covering another pixel of their screen.
    private var halo: Color {
        AuraHalo.color(from: spotifyService.artworkAverageColor) ?? .white
    }

    var body: some View {
        ZStack {
            // Completely transparent background
            Color.clear

            VStack(spacing: 8 * currentSize.scaleFactor) {
                // ERRH-03: degraded check before state switch — health trumps playback state
                if spotifyService.isDegraded {
                    Spacer()
                    VStack(spacing: 8 * currentSize.scaleFactor) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: currentSize.statusFontSize * 1.8))
                            .foregroundStyle(.white.opacity(0.6))
                        Text("Spotify connection degraded")
                            .font(.system(size: currentSize.statusFontSize, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.8))
                        Text("AppleScript is not responding")
                            .font(.system(size: currentSize.statusFontSize * 0.85, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.4))
                    }
                    Spacer()
                } else {
                switch lyricsManager.state {
                case .loading:
                    ProgressView()
                        .scaleEffect(0.8 * currentSize.scaleFactor)

                case .loaded(let lines):
                    if let activeID = lyricsManager.activeLineID,
                       let index = lines.firstIndex(where: { $0.id == activeID }) {

                        // --- ACTIVE LYRICS MODE ---

                        // PREVIOUS LINE
                        if index > 0 {
                            let prevLine = lines[index - 1]
                            HaloLine(text: prevLine.text,
                                     font: .system(size: currentSize.inactiveFontSize, weight: .semibold, design: .rounded),
                                     color: inactiveColor,
                                     halo: halo,
                                     glowRadius: 7 * currentSize.scaleFactor,
                                     glowOpacity: 0.22,
                                     lineLimit: 1, minScale: 0.8, textBlur: 1)
                                .scaleEffect(inactiveScale)
                                .frame(minHeight: currentSize.inactiveLineHeight)
                                .transition(.opacity)
                        } else {
                            Spacer().frame(height: currentSize.inactiveLineHeight)
                        }

                        // CURRENT LINE
                        HaloLine(text: lines[index].text,
                                 font: .system(size: currentSize.activeFontSize, weight: .heavy, design: .rounded),
                                 color: activeColor,
                                 halo: halo,
                                 glowRadius: 12 * currentSize.scaleFactor,
                                 glowOpacity: 0.95)
                            .scaleEffect(activeScale)
                            .frame(minHeight: currentSize.activeLineHeight)
                            .padding(.vertical, 4 * currentSize.scaleFactor)
                            .transition(.scale)
                            .id(activeID)

                        // NEXT LINE
                        if index < lines.count - 1 {
                            let nextLine = lines[index + 1]
                            HaloLine(text: nextLine.text,
                                     font: .system(size: currentSize.inactiveFontSize, weight: .semibold, design: .rounded),
                                     color: inactiveColor,
                                     halo: halo,
                                     glowRadius: 7 * currentSize.scaleFactor,
                                     glowOpacity: 0.22,
                                     lineLimit: 1, minScale: 0.8, textBlur: 1)
                                .scaleEffect(inactiveScale)
                                .frame(minHeight: currentSize.inactiveLineHeight)
                                .transition(.opacity)
                        } else {
                            Spacer().frame(height: currentSize.inactiveLineHeight)
                        }

                    } else {
                        // --- INTRO / INFO MODE (No active line yet) ---
                        if !spotifyService.currentState.track.isEmpty {
                            VStack(spacing: 4 * currentSize.scaleFactor) {
                                HaloLine(text: spotifyService.currentState.track,
                                         font: .system(size: currentSize.trackTitleFontSize, weight: .bold, design: .rounded),
                                         color: .white,
                                         halo: halo,
                                         glowRadius: 10 * currentSize.scaleFactor,
                                         glowOpacity: 0.85,
                                         lineLimit: 1, minScale: 0.8)
                                    .padding(.horizontal, 20 * currentSize.scaleFactor)

                                Text(spotifyService.currentState.artist)
                                    .font(.system(size: currentSize.artistFontSize, weight: .medium, design: .rounded))
                                    .foregroundStyle(.white.opacity(0.7))
                                    .lineLimit(1)
                                    .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)

                                if !lines.isEmpty && !lyricsManager.isSynced {
                                    Text("Lyrics not synced")
                                        .font(.system(size: currentSize.statusFontSize, weight: .bold, design: .rounded))
                                        .textCase(.uppercase)
                                        .foregroundStyle(.white.opacity(0.4))
                                        .padding(.top, 4 * currentSize.scaleFactor)
                                }
                            }
                            .transition(.opacity)
                        } else {
                            Text(spotifyService.currentState.isSpotifyRunning ? "Waiting for music..." : "Please Open Spotify")
                                .font(.system(size: currentSize.waitingFontSize, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.5))
                                .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
                        }
                    }

                case .notFound(let track, let artist):
                    // ERRH-01: show track info + "No lyrics available" in Aura mode
                    VStack(spacing: 4 * currentSize.scaleFactor) {
                        HaloLine(text: track,
                                 font: .system(size: currentSize.trackTitleFontSize, weight: .bold, design: .rounded),
                                 color: .white,
                                 halo: halo,
                                 glowRadius: 10 * currentSize.scaleFactor,
                                 glowOpacity: 0.85,
                                 lineLimit: 1, minScale: 0.8)
                            .padding(.horizontal, 20 * currentSize.scaleFactor)
                        Text(artist)
                            .font(.system(size: currentSize.artistFontSize, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1)
                            .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
                        Text("No lyrics available")
                            .font(.system(size: currentSize.statusFontSize, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.4))
                    }

                case .instrumental(let track, let artist):
                    // ERRH-02: music note + "Instrumental" in Aura mode
                    VStack(spacing: 4 * currentSize.scaleFactor) {
                        Image(systemName: "music.note")
                            .font(.system(size: currentSize.activeFontSize * 0.8))
                            .foregroundStyle(.white.opacity(0.6))
                        HaloLine(text: track,
                                 font: .system(size: currentSize.trackTitleFontSize, weight: .bold, design: .rounded),
                                 color: .white,
                                 halo: halo,
                                 glowRadius: 10 * currentSize.scaleFactor,
                                 glowOpacity: 0.85,
                                 lineLimit: 1, minScale: 0.8)
                            .padding(.horizontal, 20 * currentSize.scaleFactor)
                        Text(artist)
                            .font(.system(size: currentSize.artistFontSize, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.7))
                            .lineLimit(1)
                            .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
                        Text("Instrumental")
                            .font(.system(size: currentSize.statusFontSize, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.4))
                    }

                case .error(let message):
                    Text(message)
                        .font(.system(size: currentSize.statusFontSize, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                        .shadow(color: .black, radius: 1)

                case .idle:
                    // Not playing / waiting for track
                    if !spotifyService.currentState.track.isEmpty {
                        VStack(spacing: 4 * currentSize.scaleFactor) {
                            HaloLine(text: spotifyService.currentState.track,
                                     font: .system(size: currentSize.trackTitleFontSize, weight: .bold, design: .rounded),
                                     color: .white,
                                     halo: halo,
                                     glowRadius: 10 * currentSize.scaleFactor,
                                     glowOpacity: 0.85,
                                     lineLimit: 1, minScale: 0.8)
                                .padding(.horizontal, 20 * currentSize.scaleFactor)
                            Text(spotifyService.currentState.artist)
                                .font(.system(size: currentSize.artistFontSize, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.7))
                                .lineLimit(1)
                                .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
                        }
                        .transition(.opacity)
                    } else {
                        Text(spotifyService.currentState.isSpotifyRunning ? "Waiting for music..." : "Please Open Spotify")
                            .font(.system(size: currentSize.waitingFontSize, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                            .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
                    }
                }
                } // end else (not degraded)
            }
            .padding(.horizontal, 20 * currentSize.scaleFactor)
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: lyricsManager.activeLineID)
            .animation(.easeInOut(duration: 1.2), value: spotifyService.artworkAverageColor)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentSize)
        }
        .edgesIgnoringSafeArea(.all)
    }
}

/// One line of Aura-mode text with the album-coloured halo behind it.
///
/// The halo is a separate blurred copy of the glyphs rather than a chain of `.shadow`
/// modifiers: chaining makes SwiftUI rasterise the text together with its black legibility
/// shadow, and every later shadow is then cast by that composite — which draws a visible dark
/// contour around the whole line. Two layers keep the glow attached to the letterforms.
private struct HaloLine: View {
    let text: String
    let font: Font
    let color: Color
    let halo: Color
    let glowRadius: CGFloat
    let glowOpacity: Double
    var lineLimit: Int = 2
    var minScale: CGFloat = 0.6
    var textBlur: CGFloat = 0

    var body: some View {
        ZStack {
            Text(text)
                .font(font)
                .foregroundStyle(halo.opacity(glowOpacity))
                .blur(radius: glowRadius)

            Text(text)
                .font(font)
                .foregroundStyle(color)
                .blur(radius: textBlur)
                .shadow(color: .black.opacity(0.85), radius: 2, x: 0, y: 1)
        }
        .multilineTextAlignment(.center)
        .lineLimit(lineLimit)
        .minimumScaleFactor(minScale)
    }
}
