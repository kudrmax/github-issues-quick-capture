/// Scores how well a query matches a candidate. Higher is better, `nil` means no match.
/// Tiers: exact > prefix > substring > in-order subsequence.
public struct FuzzyMatcher: Sendable {
    static let exactScore = 1000
    static let prefixScore = 800
    static let substringScore = 600
    static let substringFloor = 450
    static let subsequenceCeiling = 399

    public init() {}

    public func score(_ query: String, in candidate: String) -> Int? {
        let needle = query.lowercased().filter { !$0.isWhitespace }
        guard !needle.isEmpty else { return 0 }
        let haystack = candidate.lowercased()

        if haystack == needle { return Self.exactScore }
        if haystack.hasPrefix(needle) { return Self.prefixScore }
        if let range = haystack.range(of: needle) {
            let offset = haystack.distance(from: haystack.startIndex, to: range.lowerBound)
            return max(Self.substringFloor, Self.substringScore - offset)
        }
        return subsequenceScore(needle, in: haystack)
    }

    private func subsequenceScore(_ needle: String, in haystack: String) -> Int? {
        var remaining = needle[...]
        var score = 0
        var streak = 0
        for character in haystack {
            guard let next = remaining.first else { break }
            if character == next {
                streak += 1
                score += streak
                remaining = remaining.dropFirst()
            } else {
                streak = 0
            }
        }
        return remaining.isEmpty ? min(score, Self.subsequenceCeiling) : nil
    }
}
