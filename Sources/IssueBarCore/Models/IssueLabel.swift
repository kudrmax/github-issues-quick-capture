public struct IssueLabel: Codable, Hashable, Identifiable, Sendable {
    public let name: String
    /// Hex without `#`, as GitHub returns it, e.g. "d73a4a".
    public let color: String
    public let description: String?

    public init(name: String, color: String, description: String? = nil) {
        self.name = name
        self.color = color
        self.description = description
    }

    public var id: String { name }
}
