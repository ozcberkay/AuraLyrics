import Foundation

public enum LRCParseError: Error, Sendable {
    case regexCompilationFailed
}

public struct LRCParser {
    public static func parse(lrcContent: String) -> Result<[LyricsLine], LRCParseError> {
        var lines: [LyricsLine] = []

        let pattern = "\\[(\\d+):(\\d+)(?:\\.|:)(\\d+)\\](.*)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return .failure(.regexCompilationFailed)
        }

        let nsString = lrcContent as NSString
        let results = regex.matches(in: lrcContent, options: [], range: NSRange(location: 0, length: nsString.length))

        for match in results {
            if match.numberOfRanges >= 5 {
                let minutesStr = nsString.substring(with: match.range(at: 1))
                let secondsStr = nsString.substring(with: match.range(at: 2))
                let hundredthsStr = nsString.substring(with: match.range(at: 3))
                let text = nsString.substring(with: match.range(at: 4)).trimmingCharacters(in: .whitespacesAndNewlines)

                if let minutes = Double(minutesStr),
                   let seconds = Double(secondsStr),
                   let hundredths = Double(hundredthsStr) {

                    // Divide by 10^digitCount so a 3-digit "567" becomes 0.567, not 5.67
                    let digitCount = Double(hundredthsStr.count)
                    let divisor = pow(10.0, digitCount)
                    let fractionalSeconds = hundredths / divisor
                    let startTime = (minutes * 60.0) + seconds + fractionalSeconds
                    lines.append(LyricsLine(id: UUID(), startTime: startTime, text: text, isSynced: true))
                }
            }
        }

        // Sometimes lines are out of order in LRC files, so sort by time
        return .success(lines.sorted { $0.startTime < $1.startTime })
    }
}
