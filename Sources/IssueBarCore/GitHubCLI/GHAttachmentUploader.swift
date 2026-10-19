import Foundation

/// GitHub has no public API for issue attachments, so images are committed to a
/// dedicated orphan branch of the same repository and linked from the issue.
/// The branch shares no history with the main branches, and the images are
/// visible to everyone who can see the repository.
public final class GHAttachmentUploader: AttachmentUploader {
    public static let branch = "issue-attachments"
    static let commitMessage = "Add issue attachment"

    private let gh: GHExecuting
    private let makePath: @Sendable (DraftImage) -> String

    public init(
        gh: GHExecuting,
        makePath: @escaping @Sendable (DraftImage) -> String = { "images/\(UUID().uuidString.lowercased()).\($0.fileExtension)" }
    ) {
        self.gh = gh
        self.makePath = makePath
    }

    public func upload(_ images: [DraftImage], to repository: Repository) async throws -> [URL] {
        var branchExists = try await isBranchPresent(in: repository)
        var urls: [URL] = []
        for image in images {
            let path = makePath(image)
            if branchExists {
                try await putFile(image, at: path, in: repository)
            } else {
                try await createBranch(withFirstFile: image, at: path, in: repository)
                branchExists = true
            }
            urls.append(Self.url(for: path, in: repository))
        }
        return urls
    }

    static func url(for path: String, in repository: Repository) -> URL {
        URL(string: "https://github.com/\(repository.nameWithOwner)/blob/\(branch)/\(path)?raw=true")!
    }

    private func isBranchPresent(in repository: Repository) async throws -> Bool {
        do {
            _ = try await gh.run(["api", "repos/\(repository.nameWithOwner)/branches/\(Self.branch)"])
            return true
        } catch GHError.commandFailed(let message) where message.contains("HTTP 404") {
            return false
        }
    }

    private func putFile(_ image: DraftImage, at path: String, in repository: Repository) async throws {
        let body: [String: Any] = [
            "message": Self.commitMessage,
            "branch": Self.branch,
            "content": image.data.base64EncodedString(),
        ]
        _ = try await gh.run(
            ["api", "-X", "PUT", "repos/\(repository.nameWithOwner)/contents/\(path)", "--input", "-"],
            input: try JSONSerialization.data(withJSONObject: body)
        )
    }

    private func createBranch(withFirstFile image: DraftImage, at path: String, in repository: Repository) async throws {
        let git = "repos/\(repository.nameWithOwner)/git"
        let blob = try await post("\(git)/blobs", ["content": image.data.base64EncodedString(), "encoding": "base64"])
        let tree = try await post("\(git)/trees", ["tree": [["path": path, "mode": "100644", "type": "blob", "sha": blob]]])
        let commit = try await post("\(git)/commits", ["message": Self.commitMessage, "tree": tree, "parents": [String]()])
        _ = try await post("\(git)/refs", ["ref": "refs/heads/\(Self.branch)", "sha": commit])
    }

    /// Returns the `sha` of the created object.
    private func post(_ endpoint: String, _ body: [String: Any]) async throws -> String {
        let output = try await gh.run(
            ["api", "-X", "POST", endpoint, "--input", "-", "--jq", ".sha // .object.sha"],
            input: try JSONSerialization.data(withJSONObject: body)
        )
        let sha = String(decoding: output, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        guard !sha.isEmpty else { throw GHError.unexpectedOutput(sha) }
        return sha
    }
}
