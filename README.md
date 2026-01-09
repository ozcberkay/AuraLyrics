# AuraLyrics

**AuraLyrics** is a minimalist, refined Spotify lyrics application for macOS. It features a beautiful, server-side rendered floating window that displays synchronized lyrics in real-time.

![AuraLyrics](https://placeholder-image-url-if-you-have-one.png)

## Features

*   **Always-on-Top Floating Window**: Lyrics float seamlessly over your other apps.
*   **Menu Bar Integration**: Control playback and see song info directly from the menu bar.
*   **Synchronized Lyrics**: Fetches time-synced lyrics automatically.
*   **Borderless Design**: Modern, clean, and distraction-free interface (best for using while working).
*   **Direct Spotify Control**: Play/Pause, Next, Previous directly from the app.

## Installation

### Via Homebrew (Recommended)

```bash
brew tap ozcberkay/tap
brew install --cask auralyrics
```

### Manual Installation

1.  Download the latest release from the [Releases](https://github.com/berkayozcan/AuraLyrics/releases) page.
2.  Unzip `AuraLyrics.tar.gz`.
3.  Drag `AuraLyrics.app` to your Applications folder.

## Usage

1.  Open **Spotify** and play a song.
2.  Open **AuraLyrics**.
3.  The lyrics will automatically appear in the floating window.
4.  Use the Menu Bar icon to toggle the window or control playback.

## Development

### Prerequisites

*   macOS 12.0+
*   Xcode 13+ (for Swift 5.5+)
*   Spotify Desktop App

### Building

```bash
git clone https://github.com/berkayozcan/AuraLyrics.git
cd AuraLyrics
swift build -c release
```

## License

This project is licensed under the MIT License - see the [LICENSE](LICENSE) file for details.
