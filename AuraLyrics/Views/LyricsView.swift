import SwiftUI

struct LyricsView: View {
    @ObservedObject var spotifyService = SpotifyService.shared
    @ObservedObject var lyricsManager = LyricsManager.shared
    
    var body: some View {
        ZStack {
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
            
            VStack(spacing: 0) {
                // Drag handle area (even if invisible)
                Rectangle()
                    .fill(Color.clear)
                    .frame(height: 20)
                
                if spotifyService.currentState.isPlaying {
                    VStack(alignment: .center, spacing: 4) {
                        Text(spotifyService.currentState.track)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .lineLimit(1)
                        Text(spotifyService.currentState.artist)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .lineLimit(1)
                            .opacity(0.7)
                            .lineLimit(1)
                            .opacity(0.7)
                    }
                    .padding(.horizontal, 40) // Prevent text from hitting the close button
                    .padding(.bottom, 10)
                    .frame(maxWidth: .infinity) // Ensure centering works despite padding
                    
                    Divider()
                        .opacity(0.3)
                    
                    if lyricsManager.isLoading {
                        Spacer()
                        ProgressView()
                            .scaleEffect(0.8)
                        Spacer()
                    } else if let error = lyricsManager.error {
                        Spacer()
                        Text(error)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .opacity(0.5)
                        Spacer()
                    } else {
                        ScrollViewReader { proxy in
                            ScrollView(showsIndicators: false) {
                                LazyVStack(spacing: 24) {
                                    Color.clear.frame(height: 150)
                                    
                                    ForEach(lyricsManager.lyrics) { line in
                                        let isActive = lyricsManager.activeLineID == line.id
                                        
                                        Text(line.text)
                                            .font(.system(size: isActive ? 24 : 20, weight: .bold, design: .rounded))
                                            .multilineTextAlignment(.center)
                                            .padding(.horizontal, 30)
                                            .foregroundStyle(isActive ? .white : .white.opacity(0.4))
                                            .blur(radius: isActive ? 0 : 0.5)
                                            .scaleEffect(isActive ? 1.05 : 1.0)
                                            .lineLimit(2) // Allow up to 2 lines
                                            .minimumScaleFactor(0.7) // Scale down if needed
                                            .fixedSize(horizontal: false, vertical: true) // Allow vertical growth
                                            .id(line.id)
                                    }
                                    
                                    Color.clear.frame(height: 200)
                                }
                            }
                            .onChange(of: lyricsManager.activeLineID) { oldID, newID in
                                if let newID = newID {
                                    withAnimation(.spring(response: 0.6, dampingFraction: 0.8)) {
                                        proxy.scrollTo(newID, anchor: .center)
                                    }
                                }
                            }
                        }
                    }
                } else {
                    Spacer()
                    VStack(spacing: 12) {
                        Image(systemName: "music.note.list")
                            .font(.system(size: 30))
                        Text("Spotify is Paused")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                    }
                    .opacity(0.5)
                    Spacer()
                }
            }
            .overlay(alignment: .topTrailing) {
                Button(action: {
                    MenuBarManager.shared.toggleList()
                }) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.system(size: 20))
                        .foregroundStyle(.white.opacity(0.3))
                }
                .buttonStyle(.plain)
                .padding(12)
                .onHover { isHovering in
                    if isHovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                }
            }
        }
        .frame(minWidth: 300, minHeight: 400)
        .edgesIgnoringSafeArea(.all)
    }
}


