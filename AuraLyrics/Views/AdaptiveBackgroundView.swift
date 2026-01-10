import SwiftUI

struct AdaptiveBackgroundView: View {
    @ObservedObject var themeManager = ThemeManager.shared
    @ObservedObject var spotifyService = SpotifyService.shared
    
    @State private var animateGradient = false
    
    var body: some View {
        Group {
            if themeManager.currentTheme == .adaptive {
                ZStack {
                    // Base dark tint to improve text contrast
                    Color.black.opacity(0.3)
                    
                    if let image = spotifyService.artworkImage, let nsColor = image.averageColor {
                        let color = Color(nsColor: nsColor)
                        
                        // Animated blobs
                        GeometryReader { geometry in
                            ZStack {
                                Circle()
                                    .fill(color.opacity(0.4))
                                    .frame(width: geometry.size.width * 0.8, height: geometry.size.width * 0.8)
                                    .offset(x: animateGradient ? -30 : 30, y: animateGradient ? -30 : 30)
                                    .blur(radius: 60)
                                
                                Circle()
                                    .fill(color.opacity(0.3))
                                    .frame(width: geometry.size.width * 0.6, height: geometry.size.width * 0.6)
                                    .offset(x: animateGradient ? 50 : -50, y: animateGradient ? 50 : -50)
                                    .blur(radius: 60)
                            }
                            .frame(maxWidth: .infinity, maxHeight: .infinity)
                        }
                    } else {
                        // Fallback default aura
                        LinearGradient(gradient: Gradient(colors: [Color.blue.opacity(0.2), Color.purple.opacity(0.2)]), startPoint: .topLeading, endPoint: .bottomTrailing)
                    }
                }
                .onAppear {
                    withAnimation(.easeInOut(duration: 5.0).repeatForever(autoreverses: true)) {
                        animateGradient.toggle()
                    }
                }
            } else if themeManager.currentTheme == .darkAura {
                Color.black.opacity(0.85)
            } else {
                // Minimalist
                Color.clear
            }
        }
        .allowsHitTesting(false)
    }
}
