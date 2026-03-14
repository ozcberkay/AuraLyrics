import SwiftUI

struct LyricsView: View {
    @ObservedObject var spotifyService = SpotifyService.shared
    @ObservedObject var lyricsManager = LyricsManager.shared

    var body: some View {
        ZStack {
            VisualEffectView(material: .hudWindow, blendingMode: .behindWindow)
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))

            AdaptiveBackgroundView()
                .clipShape(RoundedRectangle(cornerRadius: 16, style: .continuous))
                .overlay(
                    RoundedRectangle(cornerRadius: 16, style: .continuous)
                        .stroke(Color.white.opacity(0.15), lineWidth: 1)
                )

            VStack(spacing: 0) {
                // Drag handle area (even if invisible)
                Rectangle()
                    .fill(Color.clear)
                    .frame(height: 20)

                // ERRH-03: degraded check before isPlaying — health trumps playback state
                if spotifyService.isDegraded {
                    Spacer()
                    VStack(spacing: 8) {
                        Image(systemName: "exclamationmark.triangle")
                            .font(.system(size: 28))
                            .opacity(0.6)
                        Text("Spotify connection degraded")
                            .font(.system(size: 13, weight: .medium, design: .rounded))
                        Text("AppleScript is not responding")
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .opacity(0.5)
                    }
                    .opacity(0.8)
                    Spacer()
                } else if spotifyService.currentState.isPlaying {
                    VStack(alignment: .center, spacing: 4) {
                        Text(spotifyService.currentState.track)
                            .font(.system(size: 14, weight: .bold, design: .rounded))
                            .lineLimit(1)
                        Text(spotifyService.currentState.artist)
                            .font(.system(size: 11, weight: .medium, design: .rounded))
                            .lineLimit(1)
                            .opacity(0.7)
                            .shadow(color: .black.opacity(0.3), radius: 2, x: 0, y: 1)
                    }
                    .padding(.horizontal, 40) // Prevent text from hitting the close button
                    .padding(.bottom, 10)
                    .frame(maxWidth: .infinity) // Ensure centering works despite padding

                    Divider()
                        .opacity(0.3)

                    // ERRH-01/02: switch on LyricsState — replaces isLoading/error/else chain
                    switch lyricsManager.state {
                    case .idle, .loading:
                        Spacer()
                        ProgressView().scaleEffect(0.8)
                        Spacer()

                    case .notFound(let track, let artist):
                        // ERRH-01: show track info + "No lyrics available"
                        Spacer()
                        VStack(spacing: 8) {
                            Text(track)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .lineLimit(1)
                            Text(artist)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .opacity(0.7)
                                .lineLimit(1)
                            Text("No lyrics available")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .opacity(0.4)
                        }
                        .padding(.horizontal, 20)
                        Spacer()

                    case .instrumental(let track, let artist):
                        // ERRH-02: music note icon + "Instrumental"
                        Spacer()
                        VStack(spacing: 8) {
                            Image(systemName: "music.note")
                                .font(.system(size: 28))
                                .opacity(0.6)
                            Text(track)
                                .font(.system(size: 14, weight: .bold, design: .rounded))
                                .lineLimit(1)
                            Text(artist)
                                .font(.system(size: 11, weight: .medium, design: .rounded))
                                .opacity(0.7)
                                .lineLimit(1)
                            Text("Instrumental")
                                .font(.system(size: 12, weight: .medium, design: .rounded))
                                .opacity(0.4)
                        }
                        .padding(.horizontal, 20)
                        Spacer()

                    case .error(let message):
                        Spacer()
                        Text(message)
                            .font(.system(size: 12, weight: .medium, design: .rounded))
                            .opacity(0.5)
                        Spacer()

                    case .loaded(let lines):
                        ScrollViewReader { proxy in
                            ScrollView(showsIndicators: false) {
                                LazyVStack(spacing: 24) {
                                    Color.clear.frame(height: 150)

                                    if !lines.isEmpty && !lyricsManager.isSynced {
                                        Text("Lyrics not synced")
                                            .font(.system(size: 10, weight: .bold, design: .rounded))
                                            .textCase(.uppercase)
                                            .foregroundStyle(.white.opacity(0.3))
                                            .padding(.bottom, 10)
                                    }

                                    ForEach(lines) { line in
                                        let isActive = lyricsManager.activeLineID == line.id

                                        Text(line.text)
                                            .font(.system(size: isActive ? 24 : 20, weight: .bold, design: .rounded))
                                            .multilineTextAlignment(.center)
                                            .padding(.horizontal, 30)
                                            .foregroundStyle(isActive ? .white : (lyricsManager.isSynced ? .white.opacity(0.4) : .white.opacity(0.8)))
                                            .blur(radius: isActive ? 0 : (lyricsManager.isSynced ? 0.5 : 0))
                                            .shadow(color: .black.opacity(0.5), radius: 4, x: 0, y: 2)
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
                        Text(spotifyService.currentState.isSpotifyRunning ? "Spotify is Paused" : "Please Open Spotify")
                            .font(.system(size: 14, weight: .medium, design: .rounded))
                    }
                    .opacity(0.5)
                    Spacer()
                }

                // --- Aura Mode CTA ---
                VStack(spacing: 4) {
                    Divider()
                        .opacity(0.1)
                        .padding(.horizontal, 30)

                    Button(action: {
                        MenuBarManager.shared.switchToAuraMode()
                    }) {
                        HStack(spacing: 6) {
                            Image(systemName: "pip.enter")
                                .font(.system(size: 11))
                            Text("Enter Aura Mode")
                                .font(.system(size: 12, weight: .semibold, design: .rounded))
                        }
                        .foregroundStyle(.white.opacity(0.9))
                        .padding(.vertical, 6)
                        .padding(.horizontal, 14)
                        .background(
                            Capsule()
                                .fill(Color.white.opacity(0.1))
                                .overlay(
                                    Capsule()
                                        .stroke(Color.white.opacity(0.1), lineWidth: 0.5)
                                )
                        )
                    }
                    .buttonStyle(.plain)
                    .help("Enter Aura Mode")
                    .padding(.top, 6)
                    .onHover { isHovering in
                        if isHovering { NSCursor.pointingHand.push() } else { NSCursor.pop() }
                    }

                    Text("Manage views from the menu bar")
                        .font(.system(size: 9, weight: .medium, design: .rounded))
                        .foregroundStyle(.white.opacity(0.4))
                        .padding(.bottom, 10)
                }
            }
            .overlay(alignment: .topTrailing) {
                Button(action: {
                    MenuBarManager.shared.hideWindows()
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
