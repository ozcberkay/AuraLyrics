import SwiftUI

struct KaraokeView: View {
    @ObservedObject var lyricsManager = LyricsManager.shared
    @ObservedObject var spotifyService = SpotifyService.shared
    
    // Configure appearance
    private let lineHeight: CGFloat = 60
    private let activeColor = Color.white
    private let inactiveColor = Color.white.opacity(0.4)
    private let activeScale: CGFloat = 1.0
    private let inactiveScale: CGFloat = 0.8
    var body: some View {
        ZStack {
            // Completely transparent background
            Color.clear

            
            VStack(spacing: 8) {
                if lyricsManager.isLoading {
                   ProgressView()
                        .scaleEffect(0.8)
                } 
                else if let activeID = lyricsManager.activeLineID,
                          let index = lyricsManager.lyrics.firstIndex(where: { $0.id == activeID }) {
                    
                    // --- ACTIVE LYRICS MODE ---
                    
                    // PREVIOUS LINE
                    if index > 0 {
                        let prevLine = lyricsManager.lyrics[index - 1]
                        Text(prevLine.text)
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundStyle(inactiveColor)
                            .scaleEffect(inactiveScale)
                            .blur(radius: 1)
                            .lineLimit(1)
                            .frame(height: 30)
                            .transition(.opacity)
                            .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
                    } else {
                        Spacer().frame(height: 30)
                    }
                    
                    // CURRENT LINE
                    Text(lyricsManager.lyrics[index].text)
                        .font(.system(size: 32, weight: .heavy, design: .rounded))
                        .foregroundStyle(activeColor)
                        .scaleEffect(activeScale)
                        .shadow(color: .black, radius: 2, x: 0, y: 2) // Stronger shadow
                        .lineLimit(1) 
                        .frame(height: 50)
                        .transition(.scale)
                        .id(activeID)
                    
                    // NEXT LINE
                    if index < lyricsManager.lyrics.count - 1 {
                        let nextLine = lyricsManager.lyrics[index + 1]
                        Text(nextLine.text)
                            .font(.system(size: 20, weight: .semibold, design: .rounded))
                            .foregroundStyle(inactiveColor)
                            .scaleEffect(inactiveScale)
                            .blur(radius: 1)
                            .lineLimit(1)
                            .frame(height: 30)
                            .transition(.opacity)
                            .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
                    } else {
                         Spacer().frame(height: 30)
                    }
                    
                } else {
                    // --- INTRO / INFO MODE (No active text yet) ---
                    if !spotifyService.currentState.track.isEmpty {
                        VStack(spacing: 4) {
                            Text(spotifyService.currentState.track)
                                .font(.system(size: 24, weight: .bold, design: .rounded))
                                .foregroundStyle(.white)
                                .lineLimit(1)
                                .padding(.horizontal, 20)
                                .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
                            
                            Text(spotifyService.currentState.artist)
                                .font(.system(size: 16, weight: .medium, design: .rounded))
                                .foregroundStyle(.white.opacity(0.7))
                                .lineLimit(1)
                                .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
                        }
                        .transition(.opacity)
                    } else {
                        Text("Waiting for music...")
                            .font(.system(size: 16, weight: .medium, design: .rounded))
                            .foregroundStyle(.white.opacity(0.5))
                            .shadow(color: .black.opacity(0.8), radius: 2, x: 0, y: 1)
                    }
                }
            }
            .padding(.horizontal, 20)
            .animation(.spring(response: 0.5, dampingFraction: 0.8), value: lyricsManager.activeLineID)
        }
        .edgesIgnoringSafeArea(.all)
        .overlay(alignment: .bottom) {
            if let error = lyricsManager.error {
                 Text(error == "notFound" ? "Lyrics not found" : "Error: \(error)")
                    .font(.system(size: 10, weight: .medium, design: .rounded))
                    .foregroundStyle(.white.opacity(0.4))
                    .padding(.bottom, 8)
                    .shadow(color: .black, radius: 1)
            }
        }
    }
}
