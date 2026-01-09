import Foundation

struct LRCParser {
    static func parse(lrcContent: String) -> [LyricsLine] {
        var lines: [LyricsLine] = []
        
        let pattern = "\\[(\\d+):(\\d+)(?:\\.|:)(\\d+)\\](.*)"
        guard let regex = try? NSRegularExpression(pattern: pattern, options: []) else {
            return []
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
                    
                    let startTime = (minutes * 60.0) + seconds + (hundredths / 100.0)
                    lines.append(LyricsLine(startTime: startTime, text: text))
                }
            }
        }
        
        // Sometimes lines are out of order in LRC files, so sort by time
        return lines.sorted { $0.startTime < $1.startTime }
    }
}
