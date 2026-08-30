# Security

## Reporting a vulnerability

Email <hello@auraworks.dev>. Please do not open a public issue for anything that
looks exploitable — write first, and the issue can be opened afterwards once
there is a fix to point at.

Include what you did, what happened, and the macOS and AuraLyrics versions. A
proof of concept is welcome but not required.

This is a one-person project, so there is no formal response window. Expect a
first reply within a few days, and an honest answer about whether and when it
will be fixed rather than a queue position.

## What the app can actually reach

Worth knowing before you look, because it narrows the surface a great deal:

- **No server.** Nothing is operated by this project for the app to talk to.
- **No accounts, no API keys, no tokens.** Playback is read from the Spotify
  desktop app through Spotify's own scripting interface, so there are no
  credentials anywhere in the app or on disk.
- **No telemetry.** Nothing is reported anywhere.
- **No third-party dependencies.** The package declares none, so there is no
  transitive code to audit.

Two things leave the machine while the app runs, and only these two:

1. Track metadata (name, artist, album, duration) sent to `lrclib.net` to look
   up lyrics.
2. A request to Spotify's image servers (`i.scdn.co`, `mosaic.scdn.co`) for the
   album artwork the colour is drawn from.

Lyrics and artwork come back from services this project does not operate. Parsing
that response is the most interesting thing the app does with untrusted input.

## In scope

- Anything in this repository
- The parsing of lyrics, timings and artwork returned by those services
- The release archives published under Releases, and the Homebrew cask at
  [ozcberkay/homebrew-tap](https://github.com/ozcberkay/homebrew-tap)

## Not in scope

- Vulnerabilities in Spotify, LRCLIB or macOS themselves — report those to their
  own maintainers
- The fact that releases are signed ad-hoc rather than notarized. This is known,
  documented in the README, and the reason macOS asks you to approve the first
  launch.

## Supported versions

Only the latest release. Fixes ship as a new version rather than as patches to
older ones.
