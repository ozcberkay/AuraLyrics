import XCTest
import AuraLyricsCore

final class LRCParserTests: XCTestCase {

    private func parse(_ lrc: String) throws -> [LyricsLine] {
        try LRCParser.parse(lrcContent: lrc).get()
    }

    func testThreeDigitMilliseconds() throws {
        let lines = try parse("[00:01.567]hello")
        XCTAssertEqual(lines.count, 1)
        XCTAssertEqual(lines[0].startTime, 1.567, accuracy: 0.0001)
        XCTAssertEqual(lines[0].text, "hello")
        XCTAssertTrue(lines[0].isSynced)
    }

    func testTwoDigitHundredths() throws {
        let lines = try parse("[01:02.50]hello")
        XCTAssertEqual(lines.first?.startTime ?? -1, 62.5, accuracy: 0.0001)
    }

    func testMetadataTagsAreSkipped() throws {
        let lines = try parse("[ar:Some Artist]\n[ti:Some Title]\n[al:Some Album]\n[00:03.00]sung")
        XCTAssertEqual(lines.map(\.text), ["sung"])
    }

    func testLinesWithoutTimestampsAreSkipped() throws {
        let lines = try parse("no timestamp here\n\n[00:01.00]one\njust text\n[00:02.00]two")
        XCTAssertEqual(lines.map(\.text), ["one", "two"])
    }

    func testOutOfOrderLinesAreSorted() throws {
        let lines = try parse("[00:09.00]c\n[00:01.00]a\n[00:04.00]b")
        XCTAssertEqual(lines.map(\.text), ["a", "b", "c"])
        XCTAssertEqual(lines.map(\.startTime), [1, 4, 9])
    }
}
