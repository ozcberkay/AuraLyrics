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

Add tests for behaviour you change. The suite is plain XCTest in two targets and
runs in well under a second, so there is no excuse for skipping it.
`Tests/AuraLyricsCoreTests` covers the fetcher, the LRC parser and the cache key
with real behaviour tests against the Foundation-only `AuraLyricsCore` library
(HTTP is stubbed with a `URLProtocol`, no network). `Tests/AuraLyricsTests` covers
the app. Anything touching `LRCParser`, `LyricsFetcher` or the caching layer
should come with cases, because that is where the bugs have historically been.

## Releasing

Maintainers only. A `v*` tag push runs `.github/workflows/release.yml`.

1. Merge everything to release into `main` and make sure CI is green.
2. Optional dry run: Actions, Release, Run workflow, enter a version such as `1.3.0`. It builds and uploads the archive as a workflow artifact, with no release and no tap PR. Pull requests that touch the workflow or the build script run the same dry run.
3. Tag and push: `git tag v1.3.0 && git push origin v1.3.0`. The tag must be `vMAJOR.MINOR.PATCH`.
4. The workflow builds with the tag's version, checks it against the app's Info.plist, creates the GitHub Release with `AuraLyrics.tar.gz` and its SHA256, then opens a pull request on `ozcberkay/homebrew-tap` that updates `version` and `sha256` in `Casks/auralyrics.rb`.
5. Edit the release notes on GitHub, then merge the tap pull request. Users get the update with `brew upgrade --cask auralyrics`.

The tap pull request needs a `HOMEBREW_TAP_TOKEN` repository secret: a token with contents and pull request write access to the tap. Without it the workflow still publishes the release and prints a notice. Update the cask by hand with the version and the SHA256 from the release notes.

The app is ad-hoc signed, not notarized. Downloading the archive directly needs one extra step on first launch (System Settings, Privacy & Security, Open Anyway). The cask removes the quarantine attribute, so Homebrew installs are unaffected.

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
