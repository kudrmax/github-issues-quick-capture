import Foundation
import Testing
@testable import IssueBarCore

struct GHIssueTrackerTests {
    private let repository = Repository(nameWithOwner: "me/app")

    @Test func parsesRepositoriesFromJSONLines() async throws {
        let gh = FakeGH(output: """
        {"nameWithOwner":"me/app","description":"Desc","pushedAt":"2026-10-19T13:24:18Z","isPrivate":true}
        {"nameWithOwner":"org/lib","description":null,"pushedAt":null,"isPrivate":false}

        """)
        let repositories = try await GHIssueTracker(gh: gh).repositories()

        #expect(repositories.map(\.nameWithOwner) == ["me/app", "org/lib"])
        #expect(repositories[0].isPrivate)
        #expect(repositories[0].pushedAt == ISO8601DateFormatter().date(from: "2026-10-19T13:24:18Z"))
        #expect(repositories[1].pushedAt == nil)
        #expect(gh.receivedArguments.first?.prefix(2) == ["api", "--paginate"])
    }

    @Test func parsesIssues() async throws {
        let gh = FakeGH(output: """
        [{"number":3,"title":"Bug","url":"https://github.com/me/app/issues/3",
          "author":{"login":"max"},"createdAt":"2026-10-01T10:00:00Z","updatedAt":"2026-10-02T12:00:00Z","labels":[{"name":"bug"}]}]
        """)
        let issues = try await GHIssueTracker(gh: gh).issues(in: repository)

        #expect(issues.count == 1)
        #expect(issues[0].number == 3)
        #expect(issues[0].author == "max")
        #expect(issues[0].labels == ["bug"])
        #expect(issues[0].updatedAt == ISO8601DateFormatter().date(from: "2026-10-02T12:00:00Z"))
        #expect(gh.receivedArguments.first?.contains("me/app") == true)
    }

    @Test func createsIssueAndReturnsItsURL() async throws {
        let gh = FakeGH(output: "\nCreating issue in me/app\n\nhttps://github.com/me/app/issues/42\n")
        let draft = try #require(IssueDraft(text: "Title\nBody"))
        let created = try await GHIssueTracker(gh: gh).createIssue(draft, labels: [], in: repository)

        #expect(created.url.absoluteString == "https://github.com/me/app/issues/42")
        #expect(created.number == 42)
        #expect(gh.receivedArguments.first == ["issue", "create", "-R", "me/app", "--title", "Title", "--body", "Body"])
    }

    @Test func passesEachLabelAsSeparateFlag() async throws {
        let gh = FakeGH(output: "https://github.com/me/app/issues/43\n")
        let draft = try #require(IssueDraft(text: "Title"))
        let labels = [IssueLabel(name: "bug", color: "d73a4a"), IssueLabel(name: "help wanted", color: "008672")]
        _ = try await GHIssueTracker(gh: gh).createIssue(draft, labels: labels, in: repository)

        #expect(gh.receivedArguments.first?.suffix(4) == ["--label", "bug", "--label", "help wanted"])
    }

    @Test func parsesLabels() async throws {
        let gh = FakeGH(output: """
        [{"color":"d73a4a","description":"Something isn't working","name":"bug"},
         {"color":"a2eeef","description":"","name":"enhancement"}]
        """)
        let labels = try await GHIssueTracker(gh: gh).labels(in: repository)

        #expect(labels == [
            IssueLabel(name: "bug", color: "d73a4a", description: "Something isn't working"),
            IssueLabel(name: "enhancement", color: "a2eeef", description: ""),
        ])
        #expect(gh.receivedArguments.first?.prefix(4) == ["label", "list", "-R", "me/app"])
    }

    @Test func createWithoutURLInOutputFails() async throws {
        let draft = try #require(IssueDraft(text: "Title"))
        await #expect(throws: GHError.self) {
            try await GHIssueTracker(gh: FakeGH(output: "something odd")).createIssue(draft, labels: [], in: repository)
        }
    }

    @Test func mapsAuthFailure() {
        #expect(GHError.fromFailure(stderr: "To get started with GitHub CLI, please run:  gh auth login") == .notAuthenticated)
        #expect(GHError.fromFailure(stderr: "HTTP 404") == .commandFailed("HTTP 404"))
    }
}
