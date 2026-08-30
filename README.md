# AuraLyrics

[![CI](https://github.com/ozcberkay/AuraLyrics/actions/workflows/ci.yml/badge.svg)](https://github.com/ozcberkay/AuraLyrics/actions/workflows/ci.yml)

Floating, always-on-top synced lyrics for Spotify on macOS. Native Swift and SwiftUI, no third-party libraries, no Spotify API keys.

Made by [Berkay Özcan](https://auraworks.dev).

![Aura mode: three borderless lines of lyrics floating over the desktop, the active line ringed by a halo in the colour of the album art](assets/aura-mode.gif)

**Aura mode.** Three lines over your work: previous, current, next. No window and no background. The colour of the album art shows up as a halo on the current line, and fades to the next album's colour when the track changes.

![Lyrics view: the full song scrolling over an ambient background that shifts from blue to gold to orange as tracks change](assets/lyrics-mode.gif)

**Lyrics view.** The whole song, scrolling, with the same album colour spread behind it.

## Install

```bash
brew install --cask ozcberkay/tap/auralyrics
```

Homebrew is the easiest route. The cask clears the quarantine flag, so the app opens straight away.

Writing the tap name in full is what keeps this to one command. Homebrew taps it and trusts that one cask because you asked for it by name. If you run `brew tap` first and then `brew install --cask auralyrics`, you need `brew trust ozcberkay/tap` in between.

**Downloading the archive instead?** Releases are signed ad-hoc rather than notarized, so macOS blocks the first launch. Open the app once, then go to **System Settings → Privacy & Security** and click **Open Anyway** next to the AuraLyrics warning. Right-click → Open no longer works for this on macOS 15 and later.

## Usage

1. Play a song in **Spotify**.
2. Launch **AuraLyrics**. macOS asks for permission to control Spotify, which is how the app reads the current track. Grant it.
3. Lyrics appear in the floating window and follow playback.
4. The menu bar icon toggles the window, switches between the two views, changes theme and size, and controls playback.

## Features

- **Two views, one keystroke apart.** The lyrics view scrolls the whole song over a background coloured by the album art. Aura mode strips that down to three borderless lines floating over whatever you are working on, with the album colour on the words instead of behind them, so it covers nothing.
- **Always on top.** Both views stay visible over other apps.
- **Synced lyrics.** Time-synced where available, plain text otherwise.
- **Menu bar controls.** Play/pause, next, previous, current track, theme and size.
- **Two-layer cache.** Memory and disk, so a song you have already played appears instantly.
- **No accounts, no API keys, no telemetry.**

## Requirements

- macOS 14.0 (Sonoma) or later
- Spotify desktop app

Spotify only. Apple Music already shows lyrics in the Music app, and supporting it would need a different integration.

## Development

```bash
git clone https://github.com/ozcberkay/AuraLyrics.git
cd AuraLyrics
swift build
swift test
swift run AuraLyrics
```

Swift 5.9 / Xcode 15 or later. Run `scripts/build_release_auralyrics.sh` to produce a distributable `.app` and its SHA256.

The package targets Swift 5 language mode and builds with zero warnings. It also compiles under full Swift 6 language mode. Building Swift 5 with `-strict-concurrency=complete` still reports diagnostics in `WindowManager` about calling main-actor `NSWindow` methods from a nonisolated context. Swift 6's region-based isolation analysis accepts the same code, so those are not tracked as defects.

## Lyrics, privacy and legal

Lyrics come from the [LRCLIB](https://lrclib.net) community database. AuraLyrics ships no lyrics of its own and shows whatever LRCLIB returns.

What leaves your machine: the track name, artist, album and duration of the song you are playing, sent to lrclib.net to look up its lyrics, plus a request to Spotify's image CDN for the album artwork. Nothing else. There is no analytics, no account, no crash reporting, and no server run by this project. Track metadata and fetched lyrics are cached on your own disk.

AuraLyrics is an independent project with no affiliation to Spotify or LRCLIB. It reads playback state through Spotify's own scripting interface and never handles your Spotify credentials.

Rights holders: for a takedown or correction about lyrics content, open an issue here. The content itself is served by lrclib.net rather than by this app.

## Who makes this

Berkay Özcan writes and maintains AuraLyrics. AuraWorks is the name the work is published under.

Bug reports and questions are welcome in [Issues](https://github.com/ozcberkay/AuraLyrics/issues) — see [CONTRIBUTING.md](CONTRIBUTING.md) before opening a pull request. Security problems go to <hello@auraworks.dev> instead of Issues; [SECURITY.md](SECURITY.md) says what is in scope. Other projects are at [auraworks.dev](https://auraworks.dev).

## License

MIT, see [LICENSE](LICENSE). This covers the AuraLyrics source code, not any lyrics it displays.
