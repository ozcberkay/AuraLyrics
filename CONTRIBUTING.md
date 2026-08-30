# Contributing

Bug reports are the most useful thing you can send. Pull requests are welcome
too, with one caveat worth reading before you spend an evening on one.

## Before you build something large

This is a one-person project with an opinionated design, and the design is the
point: no third-party dependencies, no accounts, no telemetry, and an overlay
that covers as little of your screen as it can get away with. A change that
works against any of those is likely to be declined however well it is written.

So for anything beyond a fix, open an issue first and let's agree on the shape.
That costs you five minutes and can save you a weekend.

## Getting set up

```bash
git clone https://github.com/ozcberkay/AuraLyrics.git
cd AuraLyrics
swift build
swift test
swift run AuraLyrics
```

Swift 5.9 / Xcode 15 or later, macOS 14 or later. There is nothing else to
install — the package has no dependencies.

To produce a distributable `.app` and its SHA256, run
`scripts/build_release_auralyrics.sh`.

## What CI will check

Both of these run on every pull request, and both must pass:

```bash
swift build --build-tests && swift test
swift build -Xswiftc -swift-version -Xswiftc 6
```

The second one is not optional. The README claims the package compiles under
full Swift 6 language mode, and that claim is only worth making if it stays
true.

## Tests

Add tests for behaviour you change. The suite is plain XCTest under
`Tests/AuraLyricsTests` and runs in well under a second, so there is no excuse
for skipping it. Anything touching `LRCParser`, `LyricsFetcher` or the caching
layer should come with cases — that is where the bugs have historically been.

## Commits

- Present tense, lower case, no trailing full stop: `fix: cache collisions on
  short tracks`
- Conventional prefixes: `feat`, `fix`, `docs`, `test`, `chore`, `refactor`
- Say what changed and why. Internal ticket numbers mean nothing to anyone
  reading the history later — the early history has some, and they are a mistake
  worth not repeating.
- English, to match the rest of the history

## Pull requests

Target `main`. Keep one concern per pull request; two unrelated fixes in one
branch take twice as long to review and get reverted together when one of them
turns out to be wrong.

Describe what a reviewer should look at, and say how you tested it — "ran the
suite" is fine, "played a track with unsynced lyrics and watched the fallback"
is better.

## Reporting a bug

Open an [issue](https://github.com/ozcberkay/AuraLyrics/issues) with your macOS
version, the AuraLyrics version from the menu bar, and what the app did instead
of what you expected. If it involves a specific song, name it — lyrics come from
a community database and some entries are simply malformed.

Security problems go to <hello@auraworks.dev> instead, not to issues. See
[SECURITY.md](SECURITY.md).
