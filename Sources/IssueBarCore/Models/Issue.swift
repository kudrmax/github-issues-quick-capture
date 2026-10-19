import Foundation

public struct Issue: Hashable, Identifiable, Sendable {
    public let number: Int
    public let title: String
    public let url: URL
    public let author: String
    public let createdAt: Date
    /// Changes on any edit, label change or comment; an untouched issue keeps its creation date.
    public let updatedAt: Date
    public let labels: [String]

    public init(number: Int, title: String, url: URL, author: String, createdAt: Date, updatedAt: Date? = nil, labels: [String] = []) {
        self.number = number
        self.title = title
        self.url = url
        self.author = author
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.labels = labels
    }

    public var id: Int { number }
}

public struct CreatedIssue: Hashable, Sendable {
    public let url: URL

    public init(url: URL) {
        self.url = url
    }

    public var number: Int? { Int(url.lastPathComponent) }
}
