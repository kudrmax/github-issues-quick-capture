import Foundation

/// Title and Markdown body ready to be sent. Built from free-form text or a
/// `DraftDocument`: the first line becomes the title, the rest the body.
/// An overly long first line is shortened for the title and kept in full in the body.
public struct IssueDraft: Equatable, Sendable {
    public static let maxTitleLength = 120

    public let title: String
    public let body: String

    public init(title: String, body: String) {
        self.title = title
        self.body = body
    }

    public init?(text: String) {
        guard let draft = DraftDocument(text: text).makeDraft(imageURLs: []) else { return nil }
        self = draft
    }

    static func shortened(_ line: String) -> String {
        let prefix = line.prefix(maxTitleLength - 1)
        let wordBoundary = prefix.lastIndex(of: " ").map { prefix[..<$0] } ?? prefix
        let cut = wordBoundary.trimmingCharacters(in: CharacterSet(charactersIn: " ,.;:-–—"))
        return cut + "…"
    }
}
