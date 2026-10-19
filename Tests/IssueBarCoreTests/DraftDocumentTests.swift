import Foundation
import Testing
@testable import IssueBarCore

struct DraftDocumentTests {
    private let first = DraftImage.fake(1)
    private let second = DraftImage.fake(2)
    private let urls = [URL(string: "https://img.test/a.png")!, URL(string: "https://img.test/b.png")!]

    @Test func imagesStayWhereTheyWerePasted() throws {
        let document = DraftDocument(segments: [
            .text("Падает импорт\nСмотри:\n"), .image(first), .text("\nа потом\nещё\n"), .image(second),
        ])
        let draft = try #require(document.makeDraft(imageURLs: urls))

        #expect(draft.title == "Падает импорт")
        #expect(draft.body == "Смотри:\n![image](https://img.test/a.png)\nа потом\nещё\n![image](https://img.test/b.png)")
        #expect(document.images == [first, second])
    }

    @Test func titleComesFromFirstTextEvenAfterAnImage() throws {
        let document = DraftDocument(segments: [.image(first), .text("\nЗаголовок\nТекст")])
        let draft = try #require(document.makeDraft(imageURLs: [urls[0]]))

        #expect(draft.title == "Заголовок")
        #expect(draft.body == "![image](https://img.test/a.png)\nТекст")
    }

    @Test func imagesWithoutTextCannotBecomeAnIssue() {
        let document = DraftDocument(segments: [.image(first), .text("\n  \n")])
        #expect(!document.canBecomeIssue)
        #expect(document.makeDraft(imageURLs: [urls[0]]) == nil)
    }

    @Test func mismatchedImageURLsAreRejected() {
        let document = DraftDocument(segments: [.text("T\n"), .image(first)])
        #expect(document.makeDraft(imageURLs: []) == nil)
    }

    @Test func adjacentTextIsMergedAndEmptyTextDropped() {
        let document = DraftDocument(segments: [.text("a"), .text(""), .text("b"), .image(first), .text("")])
        #expect(document.segments == [.text("ab"), .image(first)])
        #expect(DraftDocument(segments: [.text("")]).isEmpty)
    }
}

struct IssueSubmitterTests {
    private let repository = Repository(nameWithOwner: "me/app")

    @Test func uploadsImagesThenCreatesIssueWithTheirLinks() async throws {
        let tracker = FakeTracker()
        let uploader = FakeUploader()
        let document = DraftDocument(segments: [.text("Title\n"), .image(.fake(1))])
        let label = IssueLabel(name: "bug", color: "d73a4a")

        _ = try await IssueSubmitter(tracker: tracker, uploader: uploader).submit(document, labels: [label], to: repository)

        #expect(uploader.uploaded == [.fake(1)])
        #expect(tracker.createdDrafts.first?.draft == IssueDraft(title: "Title", body: "![image](https://img.test/0.png)"))
        #expect(tracker.createdDrafts.first?.labels == [label])
    }

    @Test func textOnlyDraftSkipsUpload() async throws {
        let uploader = FakeUploader()
        _ = try await IssueSubmitter(tracker: FakeTracker(), uploader: uploader).submit(DraftDocument(text: "Hi"), labels: [], to: repository)
        #expect(uploader.uploaded.isEmpty)
    }

    @Test func draftWithoutTitleIsRejectedBeforeUploading() async {
        let uploader = FakeUploader()
        await #expect(throws: IssueSubmissionError.missingTitle) {
            try await IssueSubmitter(tracker: FakeTracker(), uploader: uploader)
                .submit(DraftDocument(segments: [.image(.fake(1))]), labels: [], to: repository)
        }
        #expect(uploader.uploaded.isEmpty)
    }
}
