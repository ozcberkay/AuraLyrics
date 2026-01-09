import SwiftUI

struct MenuControlsView: View {
    @ObservedObject var spotifyService = SpotifyService.shared
    
    var body: some View {
        VStack(spacing: 8) {
            // Song Info
            if spotifyService.currentState.isPlaying || !spotifyService.currentState.track.isEmpty {
                VStack(spacing: 2) {
                    Text(spotifyService.currentState.track)
                        .font(.system(size: 13, weight: .bold))
                        .lineLimit(1)
                    Text(spotifyService.currentState.artist)
                        .font(.system(size: 11))
                        .opacity(0.7)
                        .lineLimit(1)
                }
                .padding(.horizontal, 10)
            } else {
                 Text("No Music Playing")
                    .font(.system(size: 12))
                    .opacity(0.5)
            }
            
            HStack(spacing: 20) {
                // Previous
                Button(action: {
                    spotifyService.previousTrack()
                }) {
                    Image(systemName: "backward.fill")
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
                
                // Play/Pause
                Button(action: {
                    spotifyService.playPause()
                }) {
                    Image(systemName: spotifyService.currentState.isPlaying ? "pause.circle.fill" : "play.circle.fill")
                        .font(.system(size: 24))
                }
                .buttonStyle(.plain)
                
                // Next
                Button(action: {
                    spotifyService.nextTrack()
                }) {
                    Image(systemName: "forward.fill")
                        .font(.system(size: 14))
                }
                .buttonStyle(.plain)
            }
        }
        .padding(.vertical, 12)
        .padding(.horizontal, 16)
        .frame(width: 240) // Slightly wider for long titles
    }
}
