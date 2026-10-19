import Foundation

/// Filters repositories by query and orders them: match quality first,
/// then most recently used in the app, then most recently pushed.
public struct RepositoryRanker: Sendable {
    static let nameMatchBonus = 100

    private let matcher = FuzzyMatcher()
    private let layoutConverter = KeyboardLayoutConverter()

    public init() {}

    public func rank(_ repositories: [Repository], query: String, lastUsed: [String: Date]) -> [Repository] {
        let queries = [query, layoutConverter.qwertyEquivalent(of: query)].compactMap { $0 }
        return repositories
            .compactMap { repository in
                queries.compactMap { score(repository, $0) }.max().map { (repository, $0) }
            }
            .sorted { lhs, rhs in
                if lhs.1 != rhs.1 { return lhs.1 > rhs.1 }
                return isMoreRecent(lhs.0, than: rhs.0, lastUsed: lastUsed)
            }
            .map(\.0)
    }

    private func score(_ repository: Repository, _ query: String) -> Int? {
        let nameScore = matcher.score(query, in: repository.name).map { $0 + Self.nameMatchBonus }
        let fullNameScore = matcher.score(query, in: repository.nameWithOwner)
        return [nameScore, fullNameScore].compactMap { $0 }.max()
    }

    private func isMoreRecent(_ lhs: Repository, than rhs: Repository, lastUsed: [String: Date]) -> Bool {
        switch (lastUsed[lhs.id], lastUsed[rhs.id]) {
        case let (left?, right?) where left != right:
            return left > right
        case (.some, nil):
            return true
        case (nil, .some):
            return false
        default:
            let left = lhs.pushedAt ?? .distantPast
            let right = rhs.pushedAt ?? .distantPast
            return left != right ? left > right : lhs.nameWithOwner < rhs.nameWithOwner
        }
    }
}
