import SwiftUI

struct MenuControlsView: View {
    @ObservedObject var spotifyService = SpotifyService.shared
    
    var body: some View {
        VStack(spacing: 0) {
            // Song Info & Artwork
            if spotifyService.currentState.isPlaying || !spotifyService.currentState.track.isEmpty {
                VStack(spacing: 12) {
                    // Album Art - Larger and Centered
                    if let url = URL(string: spotifyService.currentState.artworkUrl), !spotifyService.currentState.artworkUrl.isEmpty {
                        AsyncImage(url: url) { phase in
                            switch phase {
                            case .success(let image):
                                image
                                    .resizable()
                                    .aspectRatio(contentMode: .fit)
                            case .failure(_):
                                Color.gray.opacity(0.3)
                            case .empty:
                                Color.gray.opacity(0.3)
                            @unknown default:
                                Color.gray.opacity(0.3)
                            }
                        }
                        .frame(width: 120, height: 120) // Larger artwork
                        .cornerRadius(8)
                        .shadow(radius: 4, y: 2)
                    } else {
                        // Placeholder
                        Image(systemName: "music.note")
                            .font(.system(size: 40))
                            .foregroundColor(.secondary)
                            .frame(width: 120, height: 120)
                            .background(Color.gray.opacity(0.2))
                            .cornerRadius(8)
                    }
                    
                    // Metadata - Centered
                    VStack(spacing: 4) {
                        Text(spotifyService.currentState.track)
                            .font(.system(size: 15, weight: .bold))
                            .multilineTextAlignment(.center)
                            .lineLimit(2)
                            .foregroundColor(.primary)
                        
                        Text(spotifyService.currentState.artist)
                            .font(.system(size: 13))
                            .opacity(0.8)
                            .multilineTextAlignment(.center)
                            .lineLimit(1)
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.top, 16)
                .padding(.bottom, 16)
            } else {
                 Text("No Music Playing")
                    .font(.system(size: 13))
                    .opacity(0.6)
                    .frame(height: 80)
            }
            
            Divider()
                .padding(.horizontal, 16)
            
            // Controls
            HStack(spacing: 32) {
                // Previous
                Button(action: {
                    spotifyService.previousTrack()
                }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 18))
                }
                .buttonStyle(.plain)
                .opacity(0.8)
                
                // Play/Pause
                Button(action: {
                    spotifyService.playPause()
                }) {
                    Image(systemName: spotifyService.currentState.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 44))
                        .symbolRenderingMode(.hierarchical) 
                        .foregroundColor(.primary)
                }
                .buttonStyle(.plain)
                
                // Next
                Button(action: {
                    spotifyService.nextTrack()
                }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 18))
                }
                .buttonStyle(.plain)
                .opacity(0.8)
            }
            .padding(.vertical, 16)
        }
        .frame(width: 260) // Adjusted width for vertical layout
    }
}
