import Foundation
@testable import IssueBarCore

final class FakeGH: GHExecuting, @unchecked Sendable {
    struct Call {
        let arguments: [String]
        let input: Data?

        var inputJSON: [String: Any]? {
            input.flatMap { try? JSONSerialization.jsonObject(with: $0) as? [String: Any] }
        }
    }

    private var responses: [Result<String, Error>]
    private let fallback: Result<String, Error>
    private(set) var calls: [Call] = []

    init(output: String = "", error: Error? = nil) {
        responses = []
        fallback = error.map { .failure($0) } ?? .success(output)
    }

    init(responses: [Result<String, Error>]) {
        self.responses = responses
        fallback = .success("")
    }

    var receivedArguments: [[String]] { calls.map(\.arguments) }

    func run(_ arguments: [String], input: Data?) async throws -> Data {
        calls.append(Call(arguments: arguments, input: input))
        let response = responses.isEmpty ? fallback : responses.removeFirst()
        return Data(try response.get().utf8)
    }
}

final class FakeTracker: IssueTracker, @unchecked Sendable {
    private(set) var createdDrafts: [(draft: IssueDraft, labels: [IssueLabel])] = []

    func repositories() async throws -> [Repository] { [] }
    func issues(in repository: Repository) async throws -> [Issue] { [] }
    func labels(in repository: Repository) async throws -> [IssueLabel] { [] }

    func createIssue(_ draft: IssueDraft, labels: [IssueLabel], in repository: Repository) async throws -> CreatedIssue {
        createdDrafts.append((draft, labels))
        return CreatedIssue(url: URL(string: "https://github.com/\(repository.nameWithOwner)/issues/1")!)
    }
}

final class FakeUploader: AttachmentUploader, @unchecked Sendable {
    private(set) var uploaded: [DraftImage] = []

    func upload(_ images: [DraftImage], to repository: Repository) async throws -> [URL] {
        uploaded += images
        return images.indices.map { URL(string: "https://img.test/\($0).png")! }
    }
}

extension DraftImage {
    static func fake(_ byte: UInt8) -> DraftImage {
        DraftImage(data: Data([byte, byte, byte]), fileExtension: "png")
    }
}
