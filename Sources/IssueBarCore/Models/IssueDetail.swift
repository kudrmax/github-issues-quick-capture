import Foundation

public struct IssueDetail: Codable, Equatable, Sendable {
    public let number: Int
    public let title: String
    public let url: URL
    public let author: String
    public let createdAt: Date
    public let updatedAt: Date
    public let labels: [IssueLabel]
    public let blocks: [IssueBodyBlock]

    public init(
        number: Int, title: String, url: URL, author: String, createdAt: Date, updatedAt: Date? = nil,
        labels: [IssueLabel], blocks: [IssueBodyBlock]
    ) {
        self.number = number
        self.title = title
        self.url = url
        self.author = author
        self.createdAt = createdAt
        self.updatedAt = updatedAt ?? createdAt
        self.labels = labels
        self.blocks = blocks
    }
}

public enum IssueBodyBlock: Codable, Equatable, Sendable {
    /// Text keeps inline Markdown (bold, code, links) for the view to render.
    case heading(level: Int, text: String)
    case paragraph(String)
    case listItem(marker: String, text: String)
    case quote(String)
    case code(String)
    case image(URL)
    case rule
}
