import AppKit
import Testing
@testable import IssueBar
import IssueBarCore

@MainActor
struct IssueDetailTests {
    private let repository = Repository(nameWithOwner: "me/app")
    private let tracker: StubTracker
    private let system = StubSystem()
    private let model: IssueBarViewModel

    init() {
        tracker = StubTracker(repositories: [repository])
        tracker.issueList = [7, 5, 2].map { number in
            IssueBarCore.Issue(number: number, title: "Issue \(number)", url: URL(string: "https://github.com/me/app/issues/\(number)")!, author: "max", createdAt: .now)
        }
        for number in [7, 5, 2] {
            tracker.details[number] = IssueDetail(
                number: number, title: "Issue \(number)", url: URL(string: "https://github.com/me/app/issues/\(number)")!,
                author: "max", createdAt: .now, labels: [], blocks: [.paragraph("Body \(number)")]
            )
        }
        model = makeModel(tracker: tracker, system: system)
    }

    private func openIssueList() async throws {
        model.start()
        try #require(await eventually { !model.repositories.isEmpty })
        model.select(mode: .browse)
        _ = model.handle(.submit)
        try #require(await eventually { model.issueDetail != nil })
    }

    @Test func issueListWidensThePanelAndLeavingNarrowsIt() async throws {
        var sizes: [NSSize] = []
        model.onPanelSizeChange = { sizes.append($0) }
        try await openIssueList()
        #expect(model.panelSize == IssueBarViewModel.widePanelSize)

        _ = model.handle(.back)

        #expect(model.panelSize == IssueBarViewModel.compactPanelSize)
        #expect(sizes == [IssueBarViewModel.widePanelSize, IssueBarViewModel.compactPanelSize])
    }

    @Test func firstIssueIsShownAndArrowsFollowTheSelection() async throws {
        try await openIssueList()
        #expect(model.issueDetail?.number == 7)

        _ = model.handle(.moveDown)
        #expect(await eventually { model.issueDetail?.number == 5 })
        #expect(model.issueDetail?.blocks == [.paragraph("Body 5")])
    }

    @Test func revisitedIssuesComeFromCache() async throws {
        try await openIssueList()
        _ = model.handle(.moveDown)
        _ = await eventually { model.issueDetail?.number == 5 }
        _ = model.handle(.moveUp)

        #expect(model.issueDetail?.number == 7)
        #expect(tracker.detailRequests == [7, 5])
    }

    @Test func fastScrollingOnlyLoadsWhereItStops() async throws {
        try await openIssueList()
        _ = model.handle(.moveDown)
        _ = model.handle(.moveDown)
        #expect(await eventually { model.issueDetail?.number == 2 })
        #expect(tracker.detailRequests == [7, 2])
    }

    @Test func clickShowsTheIssueAndCopiesItsLink() async throws {
        try await openIssueList()
        let third = model.visibleIssues[2]

        model.choose(third)

        #expect(model.selectedIndex == 2)
        #expect(system.copied == ["https://github.com/me/app/issues/2"])
        #expect(await eventually { model.issueDetail?.number == 2 })
    }

    @Test func filteringShowsTheFirstMatch() async throws {
        try await openIssueList()
        model.issueQuery = "Issue 2"
        #expect(await eventually { model.issueDetail?.number == 2 })
    }

    @Test func detailFailureIsReported() async throws {
        tracker.details[7] = nil
        model.start()
        _ = await eventually { !model.repositories.isEmpty }
        model.select(mode: .browse)
        _ = model.handle(.submit)

        #expect(await eventually { model.detailError != nil })
        #expect(model.issueDetail == nil)
    }
}
