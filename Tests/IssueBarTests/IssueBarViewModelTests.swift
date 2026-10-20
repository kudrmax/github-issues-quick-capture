import AppKit
import Testing
@testable import IssueBar
import IssueBarCore

@MainActor
struct IssueBarViewModelTests {
    private let repository = Repository(nameWithOwner: "me/app")
    private let bug = IssueLabel(name: "bug", color: "d73a4a")
    private let tracker = StubTracker(repositories: [Repository(nameWithOwner: "me/app")])
    private let uploader = StubUploader()
    private let system = StubSystem()
    private let model: IssueBarViewModel

    init() {
        tracker.labelList = [bug, IssueLabel(name: "enhancement", color: "a2eeef")]
        tracker.issueList = [
            IssueBarCore.Issue(number: 3, title: "Bug", url: URL(string: "https://github.com/me/app/issues/3")!, author: "max", createdAt: .now),
        ]
        model = makeModel(tracker: tracker, uploader: uploader, system: system)
    }

    private func openComposer() async {
        model.start()
        await eventually { !model.repositories.isEmpty }
        _ = model.handle(.submit)
        await eventually { !model.labels.isEmpty }
    }

    @Test func enterInPickerOpensComposerForSelectedRepository() async {
        await openComposer()
        #expect(model.screen == .composer(repository))
    }

    @Test func rightArrowInPickerOpensSelectedRepository() async {
        model.start()
        await eventually { !model.repositories.isEmpty }
        model.select(mode: .browse)

        #expect(model.handle(.moveRight))
        #expect(model.screen == .issueList(repository))
    }

    @Test func leftArrowInIssueListReturnsToPicker() async {
        model.start()
        await eventually { !model.repositories.isEmpty }
        model.select(mode: .browse)
        _ = model.handle(.submit)

        #expect(model.handle(.moveLeft))
        #expect(model.screen == .repositoryPicker)
    }

    @Test func horizontalArrowsAreLeftToTheTextElsewhere() async {
        await openComposer()
        #expect(model.handle(.moveLeft) == false)
        #expect(model.handle(.moveRight) == false)
        #expect(model.screen == .composer(repository))

        _ = model.handle(.back)
        #expect(model.handle(.moveLeft) == false)
        #expect(model.screen == .repositoryPicker)
    }

    @Test func enterInComposerIsLeftToTheEditorAsNewLine() async {
        await openComposer()
        model.draftSegments = [.text("Title")]

        #expect(model.handle(.submit) == false)
        #expect(tracker.created.isEmpty)
    }

    @Test func commandEnterUploadsImagesAndCreatesIssueWithLabels() async throws {
        await openComposer()
        let image = DraftImage(data: Data([1, 2, 3]), fileExtension: "png")
        model.draftSegments = [.text("Падает импорт\nвот так:\n"), .image(image), .text("\nконец")]
        _ = model.handle(.toggleLabel(0))
        let resetToken = model.draftResetToken

        #expect(model.handle(.commandSubmit))
        await eventually { model.createdIssue != nil }

        #expect(uploader.uploaded == [image])
        let created = try #require(tracker.created.first)
        #expect(created.draft.title == "Падает импорт")
        #expect(created.draft.body == "вот так:\n![image](https://img.test/0.png)\nконец")
        #expect(created.labels == [bug])
        #expect(system.copied == ["https://github.com/me/app/issues/7"])
        #expect(model.draftSegments.isEmpty)
        #expect(model.draftResetToken == resetToken + 1)
        #expect(model.selectedLabelNames.isEmpty)
    }

    @Test func issueStartingWithAnImageTakesTitleFromTheFirstText() async throws {
        await openComposer()
        let first = DraftImage(data: Data([1]), fileExtension: "png")
        let second = DraftImage(data: Data([2]), fileExtension: "png")
        model.draftSegments = [.image(first), .text("\nДобавить экспорт\nкак на скрине\n"), .image(second)]

        _ = model.handle(.commandSubmit)
        await eventually { model.createdIssue != nil }

        let created = try #require(tracker.created.first)
        #expect(created.draft.title == "Добавить экспорт")
        #expect(created.draft.body == "![image](https://img.test/0.png)\nкак на скрине\n![image](https://img.test/1.png)")
        #expect(uploader.uploaded == [first, second])
    }

    @Test func imagesWithoutTextExplainWhyNothingIsSent() async {
        await openComposer()
        model.draftSegments = [.image(DraftImage(data: Data([1]), fileExtension: "png"))]

        _ = model.handle(.commandSubmit)

        #expect(model.errorMessage == IssueSubmissionError.missingTitle.localizedDescription)
        #expect(uploader.uploaded.isEmpty)
        #expect(tracker.created.isEmpty)
    }

    @Test func uploadFailureKeepsTheDraft() async {
        await openComposer()
        uploader.error = GHError.commandFailed("HTTP 403")
        let segments: [DraftSegment] = [.text("T\n"), .image(DraftImage(data: Data([1]), fileExtension: "png"))]
        model.draftSegments = segments

        _ = model.handle(.commandSubmit)
        await eventually { !model.isSubmitting }

        #expect(model.errorMessage == "HTTP 403")
        #expect(model.draftSegments == segments)
        #expect(tracker.created.isEmpty)
    }

    @Test func labelShortcutTogglesOnAndOff() async {
        await openComposer()
        _ = model.handle(.toggleLabel(1))
        #expect(model.selectedLabelNames == ["enhancement"])
        _ = model.handle(.toggleLabel(1))
        #expect(model.selectedLabelNames.isEmpty)
        _ = model.handle(.toggleLabel(8))
        #expect(model.selectedLabelNames.isEmpty)
    }

    @Test func enterOnIssueCopiesItsLink() async {
        model.start()
        await eventually { !model.repositories.isEmpty }
        model.select(mode: .browse)
        _ = model.handle(.submit)
        await eventually { !model.visibleIssues.isEmpty }

        _ = model.handle(.submit)

        #expect(system.copied == ["https://github.com/me/app/issues/3"])
        #expect(model.notice == "Copied link to #3")
    }

    private func eventually(_ condition: () -> Bool, sourceLocation: SourceLocation = #_sourceLocation) async {
        let satisfied = await IssueBarTests.eventually(condition)
        #expect(satisfied, sourceLocation: sourceLocation)
    }
}
