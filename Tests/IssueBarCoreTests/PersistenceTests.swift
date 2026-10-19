import Foundation
import Testing
@testable import IssueBarCore

struct PersistenceTests {
    @Test func recentStoreRemembersLatestUsage() throws {
        let suite = "IssueBarTests.\(UUID().uuidString)"
        let defaults = try #require(UserDefaults(suiteName: suite))
        defer { defaults.removePersistentDomain(forName: suite) }
        let store = UserDefaultsRecentRepositoriesStore(defaults: defaults)

        store.markUsed("me/app", at: Date(timeIntervalSince1970: 100))
        store.markUsed("me/app", at: Date(timeIntervalSince1970: 200))
        store.markUsed("me/lib", at: Date(timeIntervalSince1970: 150))

        #expect(store.lastUsedDates() == [
            "me/app": Date(timeIntervalSince1970: 200),
            "me/lib": Date(timeIntervalSince1970: 150),
        ])
    }

    @Test func repositoryCacheRoundTrips() {
        let url = FileManager.default.temporaryDirectory
            .appending(path: UUID().uuidString)
            .appending(path: "repositories.json")
        let cache = FileRepositoryCache(fileURL: url)
        let repositories = [Repository(nameWithOwner: "me/app", description: "d", pushedAt: Date(timeIntervalSince1970: 1_800_000_000), isPrivate: true)]

        #expect(cache.load() == nil)
        cache.save(repositories)
        #expect(cache.load() == repositories)
    }
}
