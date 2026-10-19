import Foundation
import Testing
@testable import IssueBarCore

struct RepositoryRankerTests {
    private let ranker = RepositoryRanker()
    private let now = Date(timeIntervalSince1970: 1_800_000_000)

    private func repo(_ name: String, pushedHoursAgo hours: Double = 0) -> Repository {
        Repository(nameWithOwner: name, pushedAt: now.addingTimeInterval(-hours * 3600))
    }

    @Test func emptyQueryPutsRecentlyUsedFirstThenRecentlyPushed() {
        let repos = [repo("me/old", pushedHoursAgo: 50), repo("me/fresh", pushedHoursAgo: 1), repo("me/used", pushedHoursAgo: 100)]
        let ranked = ranker.rank(repos, query: "", lastUsed: ["me/used": now])
        #expect(ranked.map(\.nameWithOwner) == ["me/used", "me/fresh", "me/old"])
    }

    @Test func laterUsageWinsAmongUsedRepositories() {
        let repos = [repo("me/a"), repo("me/b")]
        let ranked = ranker.rank(repos, query: "", lastUsed: ["me/a": now.addingTimeInterval(-60), "me/b": now])
        #expect(ranked.map(\.nameWithOwner) == ["me/b", "me/a"])
    }

    @Test func nonMatchingRepositoriesAreFilteredOut() {
        let repos = [repo("me/anki-tools"), repo("me/backup")]
        #expect(ranker.rank(repos, query: "anki", lastUsed: [:]).map(\.nameWithOwner) == ["me/anki-tools"])
    }

    @Test func prefixMatchBeatsSubsequenceEvenIfLessRecent() {
        let repos = [repo("me/a-n-k-i", pushedHoursAgo: 0), repo("me/anki", pushedHoursAgo: 99)]
        let ranked = ranker.rank(repos, query: "anki", lastUsed: ["me/a-n-k-i": now])
        #expect(ranked.first?.nameWithOwner == "me/anki")
    }

    @Test func ownerAndSpacedWordsMatch() {
        let repos = [repo("acme/notes-second-brain"), repo("other/tool")]
        #expect(ranker.rank(repos, query: "acm", lastUsed: [:]).map(\.nameWithOwner) == ["acme/notes-second-brain"])
        #expect(ranker.rank(repos, query: "not sec", lastUsed: [:]).map(\.nameWithOwner) == ["acme/notes-second-brain"])
    }

    @Test func queryTypedInRussianLayoutStillMatches() {
        let repos = [repo("me/anything-to-anki"), repo("me/backup")]
        #expect(ranker.rank(repos, query: "фтлш", lastUsed: [:]).map(\.nameWithOwner) == ["me/anything-to-anki"])
    }

    @Test func layoutConverterLeavesLatinTextAlone() {
        #expect(KeyboardLayoutConverter().qwertyEquivalent(of: "anki") == nil)
        #expect(KeyboardLayoutConverter().qwertyEquivalent(of: "Фтлш-2") == "anki-2")
    }

    @Test func matchingIsCaseInsensitive() {
        #expect(ranker.rank([repo("me/MyRepo")], query: "myrepo", lastUsed: [:]).count == 1)
    }
}
