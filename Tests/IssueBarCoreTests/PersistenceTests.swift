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

    @Test func issueDetailCacheRoundTripsPerRepository() throws {
        let cache = FileIssueDetailCache(directory: FileManager.default.temporaryDirectory.appending(path: UUID().uuidString))
        let app = Repository(nameWithOwner: "me/app")
        let detail = IssueDetail(
            number: 7, title: "Title", url: try #require(URL(string: "https://github.com/me/app/issues/7")), author: "max",
            createdAt: Date(timeIntervalSince1970: 1_800_000_000), updatedAt: Date(timeIntervalSince1970: 1_800_000_060),
            labels: [IssueLabel(name: "bug", color: "d73a4a", description: nil)],
            blocks: [
                .heading(level: 2, text: "Steps"), .paragraph("Text"), .listItem(marker: "1.", text: "One"),
                .quote("Quote"), .code("let x = 1"), .image(try #require(URL(string: "https://example.com/a.png"))), .rule,
            ]
        )

        #expect(cache.load(number: 7, in: app) == nil)
        cache.save(detail, in: app)
        #expect(cache.load(number: 7, in: app) == detail)
        #expect(cache.load(number: 7, in: Repository(nameWithOwner: "me/lib")) == nil)
    }
}
