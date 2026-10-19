import Foundation

public struct Repository: Codable, Hashable, Identifiable, Sendable {
    public let nameWithOwner: String
    public let description: String?
    public let pushedAt: Date?
    public let isPrivate: Bool

    public init(nameWithOwner: String, description: String? = nil, pushedAt: Date? = nil, isPrivate: Bool = false) {
        self.nameWithOwner = nameWithOwner
        self.description = description
        self.pushedAt = pushedAt
        self.isPrivate = isPrivate
    }

    public var id: String { nameWithOwner }

    public var owner: String {
        nameWithOwner.split(separator: "/").first.map(String.init) ?? ""
    }

    public var name: String {
        nameWithOwner.split(separator: "/").last.map(String.init) ?? nameWithOwner
    }
}
