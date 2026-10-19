import Foundation

public protocol AttachmentUploader: Sendable {
    /// Returns one URL per image, in the same order.
    func upload(_ images: [DraftImage], to repository: Repository) async throws -> [URL]
}

public enum IssueSubmissionError: LocalizedError, Equatable {
    case missingTitle

    public var errorDescription: String? {
        "Add a line of text: it becomes the issue title"
    }
}

/// Uploads the draft's images first, then creates the issue with the images
/// embedded in the body where they were pasted.
public struct IssueSubmitter: Sendable {
    private let tracker: IssueTracker
    private let uploader: AttachmentUploader

    public init(tracker: IssueTracker, uploader: AttachmentUploader) {
        self.tracker = tracker
        self.uploader = uploader
    }

    public func submit(_ document: DraftDocument, labels: [IssueLabel], to repository: Repository) async throws -> CreatedIssue {
        guard document.canBecomeIssue else { throw IssueSubmissionError.missingTitle }
        let images = document.images
        let imageURLs = images.isEmpty ? [] : try await uploader.upload(images, to: repository)
        guard let draft = document.makeDraft(imageURLs: imageURLs) else { throw IssueSubmissionError.missingTitle }
        return try await tracker.createIssue(draft, labels: labels, in: repository)
    }
}
