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
}
