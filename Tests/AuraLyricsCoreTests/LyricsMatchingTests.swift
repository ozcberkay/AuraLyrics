import XCTest
@testable import AuraLyricsCore

final class LyricsMatchingTests: XCTestCase {
    private typealias M = LyricsMatching

    func testNormalize() {
        XCTAssertEqual(M.normalize("Kralın Kızı"), "kralin kizi")
        XCTAssertEqual(M.normalize("Don't Stop Me Now - 2011 Mix"), "dont stop me now 2011 mix")
        XCTAssertEqual(M.normalize("  AC/DC  "), "ac dc")
        XCTAssertEqual(M.normalize("Don\u{2019}t"), "dont")
        XCTAssertEqual(M.normalize("a,b.c!d?e"), "a b c d e")
        XCTAssertEqual(M.normalize("ＡＢＣ"), "abc")
        XCTAssertEqual(M.normalize("Çağrı Şöyle Ünlü"), "cagri soyle unlu")
    }

    func testSimilarity() {
        XCTAssertEqual(M.similarity("Kralın Kızı", "kralin kizi"), 1)
        XCTAssertEqual(M.similarity("abc", "xyz"), 0)
        XCTAssertEqual(M.similarity("", "abc"), 0)
        XCTAssertEqual(M.similarity("", ""), 0)
        let s = M.similarity("night", "nacht")
        XCTAssertGreaterThan(s, 0)
        XCTAssertLessThan(s, 1)
    }

    func testCleanTitleSuffixes() {
        XCTAssertEqual(M.cleanTitle("Come Together - Remastered 2009"), "Come Together")
        XCTAssertEqual(M.cleanTitle("Song - 2011 Remaster"), "Song")
        XCTAssertEqual(M.cleanTitle("Song - Live at Wembley"), "Song")
        XCTAssertEqual(M.cleanTitle("Song - Radio Edit"), "Song")
        XCTAssertEqual(M.cleanTitle("Song - Single Version"), "Song")
        XCTAssertEqual(M.cleanTitle("Song - Mono"), "Song")
        XCTAssertEqual(M.cleanTitle("Song - 2009 Mix"), "Song")
        XCTAssertEqual(M.cleanTitle("Song - remastered 2009"), "Song")
    }

    func testCleanTitleGroups() {
        XCTAssertEqual(M.cleanTitle("Song (feat. X)"), "Song")
        XCTAssertEqual(M.cleanTitle("Song [with X]"), "Song")
        XCTAssertEqual(M.cleanTitle("Song (Remastered 2015)"), "Song")
        XCTAssertEqual(M.cleanTitle("Song (Live)"), "Song")
    }

    func testCleanTitleRepeatsAndKeeps() {
        XCTAssertEqual(M.cleanTitle("Song - Remastered 2009 (feat. X)"), "Song")
        XCTAssertEqual(M.cleanTitle("Song (feat. X) - Live"), "Song")
        XCTAssertNil(M.cleanTitle("Part I - The Beginning"))
        XCTAssertNil(M.cleanTitle("Plain Title"))
        XCTAssertNil(M.cleanTitle("Delivery"))
        XCTAssertNil(M.cleanTitle("(Live)"))
    }

    func testSplitArtists() {
        XCTAssertEqual(M.splitArtists("Jay-Z, Kanye West"), ["Jay-Z", "Kanye West"])
        XCTAssertEqual(M.splitArtists("A & B"), ["A", "B"])
        XCTAssertEqual(M.splitArtists("A feat. B"), ["A", "B"])
        XCTAssertEqual(M.splitArtists("A FT. B"), ["A", "B"])
        XCTAssertEqual(M.splitArtists("A Featuring B"), ["A", "B"])
        XCTAssertEqual(M.splitArtists("A x B"), ["A", "B"])
        XCTAssertEqual(M.splitArtists("A X B"), ["A", "B"])
        XCTAssertEqual(M.splitArtists("Solo Artist"), ["Solo Artist"])
    }

    private func candidate(
        title: String = "Song", artist: String = "Band", duration: Double? = 200,
        synced: String? = "[00:01.00] hi", plain: String? = "hi", instrumental: Bool? = false
    ) -> LRCLibResponse {
        LRCLibResponse(
            id: 1, name: nil, trackName: title, artistName: artist, albumName: nil,
            duration: duration, instrumental: instrumental, plainLyrics: plain, syncedLyrics: synced)
    }

    private func pick(_ c: [LRCLibResponse], title: String = "Song", artist: String = "Band") -> LRCLibResponse? {
        M.pickBest(c, title: title, artist: artist, duration: 200)
    }

    func testPickBestDuration() {
        XCTAssertNil(pick([candidate(duration: 203.5)]))
        XCTAssertNotNil(pick([candidate(duration: 202.9)]))
        XCTAssertNil(pick([candidate(duration: nil)]))
    }

    func testPickBestOrdering() {
        let plainClose = candidate(duration: 200, synced: nil, plain: "x")
        let syncedFar = candidate(duration: 202, synced: "[00:01.00] a", plain: nil)
        XCTAssertEqual(pick([plainClose, syncedFar])?.duration, 202)
        let nearer = candidate(duration: 201)
        let farther = candidate(duration: 202)
        XCTAssertEqual(pick([farther, nearer])?.duration, 201)
        let instrumental = candidate(duration: 200, synced: nil, plain: nil, instrumental: true)
        XCTAssertEqual(pick([instrumental, plainClose])?.plainLyrics, "x")
        XCTAssertEqual(pick([instrumental])?.instrumental, true)
    }

    func testPickBestArtistAndLyrics() {
        XCTAssertNil(pick([candidate(artist: "Totally Different")]))
        XCTAssertNotNil(pick([candidate(artist: "Jay-Z, Kanye West")], artist: "Jay-Z"))
        XCTAssertNil(pick([candidate(synced: "", plain: "", instrumental: false)]))
        XCTAssertNil(pick([candidate(synced: nil, plain: nil, instrumental: nil)]))
    }

    func testPickBestArtistContainsRule() {
        XCTAssertNil(pick([candidate(artist: "xavier")], artist: "a"))
        XCTAssertNotNil(pick([candidate(artist: "Queen & David Bowie")], artist: "Queen"))
        XCTAssertNotNil(pick([candidate(artist: "Queen")], artist: "Queen & David Bowie"))
        XCTAssertNil(pick([candidate(artist: "Motive")], artist: "Mo"))
    }

    func testPickBestTitle() {
        XCTAssertNil(pick([candidate(title: "Another Tune")]))
        XCTAssertNotNil(pick([candidate(title: "Kralin Kizi")], title: "Kralın Kızı"))
        XCTAssertNotNil(pick([candidate(title: "Song - Remastered 2009")]))
    }

    // The real case (a plain text with a hidden track, a shorter synced copy) scored 0.73 on the
    // overlap coefficient while Jaccard was 0.31; unrelated songs score near 0. 0.6 sits between.
    private let plainText = """
        the lamp goes out
        I walk the long road home
        nobody counts the steps
        the lamp goes out
        hold the door for morning
        the river keeps my name
        a hidden track starts here
        quiet bells in the yard
        one more line from the extra song
        and another from the extra song
        """

    func testLyricsMatchCaseShape() {
        let synced = """
            [00:05.10]The lamp goes out
            [00:09.00]I walk the long road home
            [00:14.20]Nobody counts the steps
            [00:19.00]Hold the door for morning
            [00:24.00]A line only the synced copy has
            """
        let overlap = M.lyricsOverlap(plain: plainText, synced: synced)
        XCTAssertEqual(overlap.shared, 4)
        XCTAssertEqual(overlap.score, 0.8, accuracy: 0.001)
        XCTAssertTrue(M.lyricsMatch(plain: plainText, synced: synced))
    }

    func testLyricsMatchRejectsUnrelatedLyrics() {
        let synced = "[00:01.00]completely different words\n[00:05.00]about something else\n[00:09.00]nothing in common here"
        XCTAssertEqual(M.lyricsOverlap(plain: plainText, synced: synced).score, 0)
        XCTAssertFalse(M.lyricsMatch(plain: plainText, synced: synced))
    }

    func testLyricsMatchStripsTimestamps() {
        let synced = "[00:05.10][01:10.20]The lamp goes out\n[00:09:00] [02:00.000]I walk the long road home\n[00:14.20]Nobody counts the steps"
        XCTAssertEqual(M.lyricsOverlap(plain: plainText, synced: synced).shared, 3)
        XCTAssertTrue(M.lyricsMatch(plain: plainText, synced: synced))
    }

    func testLyricsMatchIgnoresCaseDiacriticsAndPunctuation() {
        let plain = "Çok güzel, bir gün!\nYağmur yağıyor...\nİçimde bir şarkı"
        let synced = "[00:01.00]cok guzel bir gun\n[00:04.00]YAGMUR YAGIYOR\n[00:08.00]icimde bir sarki"
        XCTAssertTrue(M.lyricsMatch(plain: plain, synced: synced))
    }

    func testLyricsMatchNeedsThreeSharedLines() {
        let plain = "line one\nline two\nline three"
        XCTAssertFalse(M.lyricsMatch(plain: plain, synced: "[00:01.00]line one\n[00:02.00]line two"))
        XCTAssertTrue(M.lyricsMatch(plain: plain, synced: "[00:01.00]line one\n[00:02.00]line two\n[00:03.00]line three"))
    }
}
