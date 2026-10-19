/// Keeps issues whose number, title, labels or author contain every word of the query.
public struct IssueFilter: Sendable {
    public init() {}

    public func filter(_ issues: [Issue], query: String) -> [Issue] {
        let words = query.lowercased().split(whereSeparator: \.isWhitespace)
        guard !words.isEmpty else { return issues }
        return issues.filter { issue in
            let searchable = searchableText(of: issue)
            return words.allSatisfy { searchable.contains($0) }
        }
    }

    private func searchableText(of issue: Issue) -> String {
        (["#\(issue.number)", issue.title, issue.author] + issue.labels)
            .joined(separator: " ")
            .lowercased()
    }
}
