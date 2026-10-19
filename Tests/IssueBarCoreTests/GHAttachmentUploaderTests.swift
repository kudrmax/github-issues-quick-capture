import Foundation
import Testing
@testable import IssueBarCore

struct GHAttachmentUploaderTests {
    private let repository = Repository(nameWithOwner: "me/app")

    private func uploader(_ gh: FakeGH) -> GHAttachmentUploader {
        let counter = Counter()
        return GHAttachmentUploader(gh: gh) { "images/\(counter.next()).\($0.fileExtension)" }
    }

    @Test func existingBranchGetsFilesThroughContentsAPI() async throws {
        let gh = FakeGH(responses: [.success("{}"), .success("{}"), .success("{}")])
        let urls = try await uploader(gh).upload([.fake(1), .fake(2)], to: repository)

        #expect(urls.map(\.absoluteString) == [
            "https://github.com/me/app/blob/issue-attachments/images/1.png?raw=true",
            "https://github.com/me/app/blob/issue-attachments/images/2.png?raw=true",
        ])
        #expect(gh.calls[0].arguments == ["api", "repos/me/app/branches/issue-attachments"])
        #expect(gh.calls[1].arguments == ["api", "-X", "PUT", "repos/me/app/contents/images/1.png", "--input", "-"])
        let body = try #require(gh.calls[1].inputJSON)
        #expect(body["branch"] as? String == "issue-attachments")
        #expect(body["content"] as? String == DraftImage.fake(1).data.base64EncodedString())
    }

    @Test func missingBranchIsCreatedAsOrphanWithTheFirstImage() async throws {
        let gh = FakeGH(responses: [
            .failure(GHError.commandFailed("gh: Branch not found (HTTP 404)")),
            .success("blob-sha\n"), .success("tree-sha\n"), .success("commit-sha\n"), .success("commit-sha\n"),
            .success("{}"),
        ])
        _ = try await uploader(gh).upload([.fake(1), .fake(2)], to: repository)

        let endpoints = gh.calls.dropFirst().map { $0.arguments[3] }
        #expect(endpoints == [
            "repos/me/app/git/blobs", "repos/me/app/git/trees", "repos/me/app/git/commits", "repos/me/app/git/refs",
            "repos/me/app/contents/images/2.png",
        ])
        #expect((gh.calls[3].inputJSON?["parents"] as? [String]) == [])
        #expect(gh.calls[3].inputJSON?["tree"] as? String == "tree-sha")
        #expect(gh.calls[4].inputJSON?["ref"] as? String == "refs/heads/issue-attachments")
        #expect(gh.calls[4].inputJSON?["sha"] as? String == "commit-sha")
    }

    @Test func otherBranchLookupErrorsAreNotSwallowed() async {
        let gh = FakeGH(error: GHError.commandFailed("HTTP 403: Forbidden"))
        await #expect(throws: GHError.commandFailed("HTTP 403: Forbidden")) {
            try await uploader(gh).upload([.fake(1)], to: repository)
        }
    }
}

private final class Counter: @unchecked Sendable {
    private var value = 0

    func next() -> Int {
        value += 1
        return value
    }
}
