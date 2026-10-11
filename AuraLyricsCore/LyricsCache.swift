import Foundation

/// Remembers lyrics lookups in memory and on disk, and decides whether a lookup
/// needs the network at all.
///
/// Found lyrics are kept for good. "No lyrics" and "instrumental" answers are kept
/// for `missLifetime` (24 hours by default, the same time LRCLIB caches its own
/// misses), so a song without lyrics does not re-run the whole fallback chain on
/// every play. Errors are temporary and are never stored.
///
/// `@unchecked Sendable`: the memory cache is an NSCache (thread-safe). Every
/// write to it that follows a disk read, and every write from `store` and `remove`,
/// runs on a private serial queue (shared by all instances), so an older disk entry
/// can never overwrite or resurrect a newer change. A memory hit stays lock-free.
/// Disk writes and deletes are queued with `async` so a slow write never blocks a
/// caller. Disk reads go through the same queue with `sync`, so they run after every
/// write issued before them: a read after `store` or `remove` returned sees that
/// change even if NSCache evicted the memory copy, and one key's file is never read
/// half-written or written by two callers at once.
public final class LyricsCache: @unchecked Sendable {

    /// What is stored per key, in memory and as the JSON file on disk.
    private struct Entry: Codable {
        enum Miss: String, Codable { case notFound, instrumental }

        var lines: [LyricsLine]?
        var miss: Miss?
        var track: String?
        var artist: String?
        var storedAt: Date?
    }

    /// NSCache needs class values.
    private final class Box {
        let entry: Entry
        init(_ entry: Entry) { self.entry = entry }
    }

    private let directory: URL?
    private let fileName: @Sendable (String) -> String
    private let now: @Sendable () -> Date
    private let missLifetime: TimeInterval
    // Shared by all instances so a new instance over the same directory (a relaunch in
    // tests) still reads after the earlier instance's pending writes.
    private static let ioQueue = DispatchQueue(label: "AuraLyrics.LyricsCache.io")

    // In-memory layer for instant track switches within a session.
    private let lyricsMemoryCache: NSCache<NSString, Box> = {
        let c = NSCache<NSString, Box>()
        c.countLimit = 50
        return c
    }()

    /// `directory` nil keeps everything in memory only. `fileName` turns a key into a
    /// file name (without extension); the app passes a SHA256 hex digest so any title
    /// gives a short, legal name.
    public init(
        directory: URL?,
        fileName: @escaping @Sendable (String) -> String,
        now: @escaping @Sendable () -> Date = Date.init,
        missLifetime: TimeInterval = 24 * 60 * 60
    ) {
        self.directory = directory
        self.fileName = fileName
        self.now = now
        self.missLifetime = missLifetime
    }

    private func fileURL(forKey key: String) -> URL? {
        directory?.appendingPathComponent(fileName(key) + ".json")
    }

    /// The cached answer for `key`, or nil when there is none or a remembered miss
    /// is older than `missLifetime`.
    public func cachedState(for key: String) -> LyricsState? {
        if let box = lyricsMemoryCache.object(forKey: key as NSString) {
            return state(from: box.entry)
        }
        // Waits for pending writes, then re-checks memory in case a store landed meanwhile.
        let entry: Entry? = Self.ioQueue.sync {
            if let box = lyricsMemoryCache.object(forKey: key as NSString) { return box.entry }
            guard let entry = loadFromDisk(key: key) else { return nil }
            lyricsMemoryCache.setObject(Box(entry), forKey: key as NSString)
            return entry
        }
        return entry.flatMap(state(from:))
    }

    /// Like `cachedState(for:)` for the current playback's key, but a served miss
    /// carries the current track and artist, not the names stored when it was cached
    /// (the same track id can come back under a renamed title).
    public func cachedState(for playback: PlaybackState) -> LyricsState? {
        switch cachedState(for: playback.lyricsCacheKey) {
        case .notFound?: return .notFound(track: playback.track, artist: playback.artist)
        case .instrumental?: return .instrumental(track: playback.track, artist: playback.artist)
        case let other: return other
        }
    }

    /// Stores a fetch result: lyrics for good, misses with the time they were stored,
    /// errors and placeholder states not at all.
    public func store(_ result: LyricsState, for key: String) {
        let entry: Entry
        switch result {
        case .loaded(let lines):
            entry = Entry(lines: lines)
        case .notFound(let track, let artist):
            entry = Entry(miss: .notFound, track: track, artist: artist, storedAt: now())
        case .instrumental(let track, let artist):
            entry = Entry(miss: .instrumental, track: track, artist: artist, storedAt: now())
        case .error, .idle, .loading:
            return
        }
        Self.ioQueue.sync { lyricsMemoryCache.setObject(Box(entry), forKey: key as NSString) }
        Self.ioQueue.async { self.saveToDisk(entry, key: key) }
    }

    /// Forgets `key` in memory and on disk.
    public func remove(_ key: String) {
        Self.ioQueue.sync { lyricsMemoryCache.removeObject(forKey: key as NSString) }
        guard let url = fileURL(forKey: key) else { return }
        Self.ioQueue.async { try? FileManager.default.removeItem(at: url) }
    }

    /// Serves `playback` from the cache, or fetches it and caches the result.
    /// `forceRefresh` (the Retry button) skips the cache read and always asks LRCLIB.
    /// The old entry is kept until a new result replaces it, so a cancelled fetch or an
    /// error leaves it in place. Returns nil when the fetch was cancelled, and caches
    /// nothing then.
    public func load(_ playback: PlaybackState, fetcher: LyricsFetcher, forceRefresh: Bool = false) async -> LyricsState? {
        let key = playback.lyricsCacheKey
        if !forceRefresh, let cached = cachedState(for: playback) {
            return cached
        }
        guard let result = await fetcher.loadState(
            track: playback.track,
            artist: playback.artist,
            album: playback.album,
            duration: playback.duration
        ) else { return nil }
        store(result, for: key)
        return result
    }

    private func state(from entry: Entry) -> LyricsState? {
        if let lines = entry.lines { return .loaded(lines) }
        guard let miss = entry.miss, let storedAt = entry.storedAt,
              now().timeIntervalSince(storedAt) < missLifetime else { return nil }
        let track = entry.track ?? ""
        let artist = entry.artist ?? ""
        switch miss {
        case .notFound: return .notFound(track: track, artist: artist)
        case .instrumental: return .instrumental(track: track, artist: artist)
        }
    }

    /// Reads the current format first, then the old bare `[LyricsLine]` files.
    /// Anything else (corrupt, empty, unknown) counts as no entry, and so does a lyrics
    /// list that is empty or all blank, which older versions could write.
    private func loadFromDisk(key: String) -> Entry? {
        guard let url = fileURL(forKey: key), let data = try? Data(contentsOf: url) else { return nil }
        if let entry = try? JSONDecoder().decode(Entry.self, from: data),
           entry.lines != nil || entry.miss != nil {
            if let lines = entry.lines, !Self.hasText(lines) { return nil }
            return entry
        }
        if let lines = try? JSONDecoder().decode([LyricsLine].self, from: data), Self.hasText(lines) {
            return Entry(lines: lines)
        }
        return nil
    }

    private static func hasText(_ lines: [LyricsLine]) -> Bool {
        lines.contains { !$0.text.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
    }

    /// A failed write is not critical: the memory layer still serves this session.
    private func saveToDisk(_ entry: Entry, key: String) {
        guard let directory, let url = fileURL(forKey: key) else { return }
        do {
            try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
            try JSONEncoder().encode(entry).write(to: url, options: .atomic)
        } catch {}
    }
}
