# Reddit ve Show HN gönderi metinleri

İki gönderime hazır metin. Dil İngilizce, çünkü ikisi de İngilizce topluluk.

- r/macapps metni: "r/macapps'te AuraLyrics gönderisini paylaş" işinde kullanılacak.
- Show HN metni: "Show HN gönderisini paylaş" işinde kullanılacak.

Metinlerdeki her olgu repo'dan doğrulandı: README.md, apps.json, Package.swift, kaynak
kod ve 29 Ağustos strateji denetimi raporu. Doğrulanan sayılar: 21 Swift dosyası,
2367 satır (metinde "yaklaşık 2.400" yazıyor), sıfır üçüncü taraf bağımlılık, 43 test.
Fiyat ücretsiz, lisans MIT, kurulum `brew install --cask ozcberkay/tap/auralyrics`,
indirme adresi `https://github.com/ozcberkay/AuraLyrics/releases/latest`.

Kurucunun dolduracağı yerler aşağıda "Yer tutucular" başlığında toplandı.

---

## r/macapps

**Başlık**

```text
[Free] AuraLyrics: floating, always-on-top synced lyrics for Spotify on macOS
```

**Alternatif başlık**

```text
[Free] I built a floating lyrics window for Spotify, native Swift, no dependencies
```

**Gönderi öncesi kontrol listesi**

- Flair: subreddit'in self-promo flair'i. Tam etiket adı [kurucu dolduracak], gönderi
  ekranındaki listeden seç.
- Fiyat başlıkta yazıyor: `[Free]`.
- İndirme bağlantısı gövdede açık: hem brew komutu hem releases adresi.
- Geliştirici olduğun gövdenin son paragrafında yazıyor.
- Klibi doğrudan Reddit'e video olarak yükle, `assets/aura-mode.gif` dosyasını kullan.
  Reddit tek gönderide hem video hem metin almazsa metni gönderi, klibi ilk yorum yap.

**Gövde**

```text
I built AuraLyrics because the Spotify desktop app still has no floating lyrics window. It shows the synced lyrics of whatever is playing, in a window that stays on top of everything else. Two views: a lyrics view that scrolls the whole song over a background coloured by the album art, and Aura mode, which strips that down to three borderless lines over your desktop with the album colour as a halo on the words instead of behind them.

[clip: Aura mode, 8 seconds, one track change]

Free, MIT licensed, source on GitHub. Nothing to buy, no trial, no pro tier.

Install with Homebrew:

brew install --cask ozcberkay/tap/auralyrics

Or download the archive: https://github.com/ozcberkay/AuraLyrics/releases/latest

Releases are ad-hoc signed rather than notarized, so macOS blocks the first launch of the archive. Open the app once, then go to System Settings, Privacy and Security, and click Open Anyway. The Homebrew cask clears the quarantine flag, so that route opens straight away.

How it reads your music: it asks the Spotify desktop app for the current track through Spotify's own scripting interface. No API keys, no OAuth, no login, and it never touches your Spotify credentials. Lyrics come from LRCLIB, the community lyrics database, so AuraLyrics ships no lyrics of its own and shows whatever LRCLIB returns.

What leaves your machine: the track name, artist, album and duration go to lrclib.net to look the lyrics up, and one request goes to Spotify's image CDN for the album art. That is all. No analytics, no telemetry, no crash reporting, no account, and no server of mine anywhere. Lyrics and track metadata are cached on your own disk.

The menu bar item toggles the window, switches between the two views, changes theme and size, and does play, pause, next and previous.

Honest limits:

- Spotify desktop app only. Apple Music users already get lyrics inside Music.app, so supporting it would mean a different integration for something you already have.
- If LRCLIB does not have the track, you get nothing. There is no search fallback yet, so a remaster or a "feat." mismatch can show up as no lyrics.
- Last tested on macOS 26.4. The build target says macOS 14 and later, but I have not verified it on 14 or 15 myself. I have not run it on the macOS 27 beta either.
- No word by word sync and no translation.

Requirements: macOS 14 or later, and the Spotify desktop app.

Why I wanted this at all: Spotify put a cap on lyrics for free accounts in 2024, its desktop full screen lyrics view got worse the same year, and there is still no floating or mini player lyrics mode on the desktop.

I am the developer and this is my own app, so treat this as self promotion. It is free with nothing to sell. Bugs and feature requests go to GitHub issues, or just tell me here and I will read it.
```

---

## Show HN

**Başlık** (77 karakter, HN'in 80 sınırının altında, "Show HN:" ile başlıyor)

```text
Show HN: AuraLyrics, floating Spotify lyrics for macOS in 2.4k lines of Swift
```

**Alternatif başlık** (69 karakter)

```text
Show HN: A floating, always-on-top lyrics window for Spotify on macOS
```

**URL alanı**

```text
https://github.com/ozcberkay/AuraLyrics
```

**Gövde** (ilk yorum olarak gönder, HN'de âdet bu)

```text
I built AuraLyrics because the Spotify desktop app still has no floating lyrics window. It puts the synced lyrics of the current track in a window that stays over everything else. Two views: the full song scrolling over a background coloured by the album art, and Aura mode, three borderless lines over the desktop with the album colour as a halo on the words instead of behind them.

Why I wanted it: Spotify capped lyrics for free accounts in 2024, the desktop full screen lyrics view regressed the same year, and there is still no floating or mini player lyrics mode on the desktop. I have Spotify open all day and wanted the words without giving up a browser tab.

How it works.

Playback state comes from the Spotify desktop app through its own AppleScript interface, plus Spotify's DistributedNotification for playback changes. No Spotify API keys, no OAuth, no account, and no sp_dc cookie scraping. NSAppleScript is neither thread safe nor Sendable, so every execution goes through a single serial queue with the script wrapped in a box to cross isolation. Polling is adaptive: every 2 seconds while playing, 5 seconds while paused, 10 seconds when Spotify is not running.

Lyrics come from LRCLIB with an identified User-Agent, a 10 second timeout, and retries at 2 and 5 seconds on transient network errors only. Cache is two layers, memory and disk. The cache key is track, artist, album and duration, not just track and artist, because the shorter key collided a live take with the studio recording of the same song. The file on disk is named by the SHA256 of that key.

The window is a borderless NSPanel hosting SwiftUI: nonactivating, floating level, canJoinAllSpaces plus fullScreenAuxiliary, so it follows you across Spaces and sits over full screen apps without stealing focus. One thing that was not obvious to me: a borderless panel derives its shadow from the alpha silhouette of its content rather than from its frame. That is what you want for the opaque lyrics card, but on Aura mode's transparent text macOS traces a dark contour around every glyph and around the glow behind them, so that panel turns the shadow off. Aura mode can also be locked click through, so it never eats a click meant for the window underneath.

The menu bar item builds its NSMenu once and afterwards only mutates the stored NSMenuItem references. Rebuilding the menu per track meant allocating NSHostingViews on every poll.

The album colour is the average colour of the artwork, obtained by resizing the image to a single pixel, then crossfaded over 1.2 seconds when the track changes. Hacky, but it costs nothing.

21 Swift files, about 2,400 lines, zero third party dependencies. Swift 5 language mode, and it also compiles under full Swift 6 language mode. 43 tests, though I will admit most of them check source text rather than behaviour.

What it does not do, honestly.

Spotify desktop only. Apple Music already shows lyrics inside Music.app, so that would be a separate integration for something you already have.

If LRCLIB does not have the track, you get nothing. There is no search fallback, so a remaster or a "feat." mismatch reads as no lyrics.

No word by word sync, no translation.

Last tested on macOS 26.4. The build target says macOS 14 and later, and I have not verified it on 14 or 15. I have not run it on the macOS 27 beta either.

Releases are ad-hoc signed, not notarized, so a direct download needs the System Settings, Privacy and Security, Open Anyway step. The Homebrew cask clears quarantine and skips that.

Free, MIT, no telemetry, no account, no server of mine. The only things that leave your machine are the track metadata sent to lrclib.net and the artwork request to Spotify's image CDN. Lyrics come from the LRCLIB community database, not from me.

brew install --cask ozcberkay/tap/auralyrics

Source: https://github.com/ozcberkay/AuraLyrics

Two things I would like feedback on. First, whether AppleScript polling is the wrong foundation here and there is a playback source I have missed. Second, whether Aura mode actually reads on a busy desktop or just turns into noise.
```

---

## Yer tutucular

Metinlerde kurucudan bekleyen tek şey şunlar:

- **r/macapps flair adı**: [kurucu dolduracak]. Subreddit'in self-promo flair'inin tam adı
  gönderi ekranından seçilecek.
- **r/macapps klip satırı**: `[clip: Aura mode, 8 seconds, one track change]` yazan yer.
  Klip Reddit'e video olarak yüklenecek, kaynak dosya `assets/aura-mode.gif`.
- **Show HN gönderim tarihi ve macOS 27 durumu**: metinde "macOS 27 beta'sında
  çalıştırılmadı" satırı duruyor. Gönderi anında macOS 27 çıkmışsa satır olduğu gibi
  kalabilir, çünkü doğruyu söylüyor. Sanal makinede test yapılırsa satır güncellenecek.

Sürüm numarası bilerek yazılmadı. `releases/latest` bağlantısı her zaman doğru sürüme
gidiyor, metnin eskimesine gerek yok.

## AlternativeTo

Bu işin beşinci adımı olan AlternativeTo listelemesi kurucuda kaldı, çünkü hesap açmak ve
gönderim formunu doldurmak giriş yapılmış bir oturum istiyor. Gönderim şu şekilde
yapılacak: AuraLyrics'i LyricsX ve LyricFever alternatifi olarak ekle, platform macOS,
lisans MIT ve ücretsiz, bağlantı `https://github.com/ozcberkay/AuraLyrics`, açıklama için
yukarıdaki r/macapps gövdesinin ilk paragrafı yeterli. MacUpdate atlanacak, DMG istiyor.
