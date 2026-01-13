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
    
    var body: some View {
        ZStack {
            // Completely transparent background
            Color.clear

            
            VStack(spacing: 8 * currentSize.scaleFactor) {
                if lyricsManager.isLoading {
                   ProgressView()
                        .scaleEffect(0.8 * currentSize.scaleFactor)
                } 
                else if let activeID = lyricsManager.activeLineID,
                          let index = lyricsManager.lyrics.firstIndex(where: { $0.id == activeID }) {
                    
                    // --- ACTIVE LYRICS MODE ---
                    
                    // PREVIOUS LINE
                    if index > 0 {
                        let prevLine = lyricsManager.lyrics[index - 1]
                        Text(prevLine.text)
                            .font(.system(size: currentSize.inactiveFontSize, weight: .semibold, design: .rounded))
                            .foregroundStyle(inactiveColor)
                            .scaleEffect(inactiveScale)
                            .blur(radius: 1)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(minHeight: currentSize.inactiveLineHeight)
                            .transition(.opacity)
                            .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
                    } else {
                        Spacer().frame(height: currentSize.inactiveLineHeight)
                    }
                    
                    // CURRENT LINE
                    Text(lyricsManager.lyrics[index].text)
                        .font(.system(size: currentSize.activeFontSize, weight: .heavy, design: .rounded))
                        .foregroundStyle(activeColor)
                        .scaleEffect(activeScale)
                        .shadow(color: .black, radius: 2, x: 0, y: 2)
                        .lineLimit(2)
                        .minimumScaleFactor(0.6)
                        .multilineTextAlignment(.center)
                        .frame(minHeight: currentSize.activeLineHeight)
                        .padding(.vertical, 4 * currentSize.scaleFactor)
                        .transition(.scale)
                        .id(activeID)
                    
                    // NEXT LINE
                    if index < lyricsManager.lyrics.count - 1 {
                        let nextLine = lyricsManager.lyrics[index + 1]
                        Text(nextLine.text)
                            .font(.system(size: currentSize.inactiveFontSize, weight: .semibold, design: .rounded))
                            .foregroundStyle(inactiveColor)
                            .scaleEffect(inactiveScale)
                            .blur(radius: 1)
                            .lineLimit(1)
                            .minimumScaleFactor(0.8)
                            .frame(minHeight: currentSize.inactiveLineHeight)
                            .transition(.opacity)
                            .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
                    } else {
                        Spacer().frame(height: currentSize.inactiveLineHeight)
                    }
                    
                } else {
                    // --- INTRO / INFO MODE (No active text yet) ---
                    if !spotifyService.currentState.track.isEmpty {
                        VStack(spacing: 4 * currentSize.scaleFactor) {
                            Text(spotifyService.currentState.track)
                                .font(.system(size: currentSize.trackTitleFontSize, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .padding(.horizontal, 20 * currentSize.scaleFactor)
                                .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
                            
                            Text(spotifyService.currentState.artist)
                                .font(.system(size: currentSize.artistFontSize, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.7))
                                .lineLimit(1)
                                .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
                            
                            if !lyricsManager.lyrics.isEmpty && !lyricsManager.isSynced {
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
            }
            .padding(.horizontal, 20 * currentSize.scaleFactor)
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: lyricsManager.activeLineID)
            .animation(.spring(response: 0.4, dampingFraction: 0.8), value: currentSize)
        }
        .edgesIgnoringSafeArea(.all)
        .overlay(alignment: .bottom) {
            if let error = lyricsManager.error {
                 Text(error == "notFound" ? "Lyrics not found" : "Error: \(error)")
                    .font(.system(size: currentSize.statusFontSize, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.bottom, 8 * currentSize.scaleFactor)
                    .shadow(color: .black, radius: 1)
            }
        }
    }
}
