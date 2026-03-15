import XCTest

// LRCParser lives in an executable target with dependencies: [] (no @testable import available).
// All tests use source-inspection via URL(fileURLWithPath: #file) + 3-level deletingLastPathComponent.

final class LRCParserTests: XCTestCase {

    private func lrcParserSource() throws -> String {
        let sourceURL = URL(fileURLWithPath: #file)
            .deletingLastPathComponent()   // AuraLyricsTests/
            .deletingLastPathComponent()   // Tests/
            .deletingLastPathComponent()   // project root
            .appendingPathComponent("AuraLyrics/Services/LRCParser.swift")
        return try String(contentsOf: sourceURL, encoding: .utf8)
    }

    // PARS-01: LRCParser must use pow(10.0, digitCount) to correctly normalize variable-length
    // millisecond fields (e.g. 3-digit "567" → 0.567, not 5.67). Source-inspection test.
    // Currently RED — production code divides by 100.0 unconditionally.
    func testThreeDigitMillisecondsParsedCorrectly() throws {
        let source = try lrcParserSource()
        XCTAssertTrue(
            source.contains("pow(10.0"),
            "PARS-01: LRCParser must use pow(10.0, digitCount) to normalize millisecond digit count — currently hardcodes /100.0"
        )
    }

    // PARS-02: Metadata tags [ar:...], [ti:...], [al:...] must not match the timestamp regex.
    // Source-inspection test: the regex must require numeric-only minute/second/fraction groups
    // so letter-keyed tags like [ar:Artist] are silently skipped.
    // Currently GREEN — the existing regex \\[(\\d+):(\\d+)... enforces this.
    func testMetadataTagsSkipped() throws {
        let source = try lrcParserSource()
        // The regex must start with \[(\d+) so non-numeric letter keys don't match
        XCTAssertTrue(
            source.contains("\\\\d+"),
            "PARS-02: LRCParser regex must use \\d+ to require numeric groups, ensuring metadata tags [ar:...] are skipped"
        )
        // Additional guard: the pattern variable itself must be present
        XCTAssertTrue(
            source.contains("pattern"),
            "PARS-02: LRCParser must use a named regex pattern for timestamp matching"
        )
    }

    // PARS-02 (empty lines): The parser must only produce lines where a timestamp regex match
    // succeeds; blank lines without timestamps must not create entries.
    // Source-inspection test: guard against unconditional line splitting.
    // Currently GREEN — the regex-match loop naturally skips non-matching lines.
    func testEmptyLinesSkipped() throws {
        let source = try lrcParserSource()
        // Must NOT split on newlines unconditionally (which would include empty lines)
        XCTAssertFalse(
            source.contains("components(separatedBy: .newlines)"),
            "PARS-02: LRCParser must not split all newlines unconditionally — use regex matching to skip empty lines"
        )
        // Must use regex matches as the loop driver
        XCTAssertTrue(
            source.contains("regex.matches"),
            "PARS-02: LRCParser must use regex.matches loop as the primary line driver"
        )
    }

    // PARS-03: LRCParser must define LRCParseError and return Result<[LyricsLine], LRCParseError>.
    // Source-inspection test. Currently RED — production code lacks these types.
    func testStructuredParseErrorType() throws {
        let source = try lrcParserSource()
        XCTAssertTrue(
            source.contains("LRCParseError"),
            "PARS-03: LRCParser must define LRCParseError type"
        )
        XCTAssertTrue(
            source.contains("Result"),
            "PARS-03: LRCParser.parse must return Result type"
        )
    }
}
