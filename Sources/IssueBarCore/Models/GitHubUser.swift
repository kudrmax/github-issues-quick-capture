import Foundation

public struct GitHubUser: Hashable, Sendable {
    public let login: String

    public init(login: String) {
        self.login = login
    }

    public var initial: String {
        login.first.map { String($0).uppercased() } ?? "?"
    }

    /// avatars.githubusercontent.com resolves a login directly, without the redirect github.com/{login}.png makes.
    public func avatarURL(pixelSize: Int) -> URL? {
        guard !login.isEmpty else { return nil }
        var components = URLComponents()
        components.scheme = "https"
        components.host = "avatars.githubusercontent.com"
        components.path = "/" + login
        components.queryItems = [URLQueryItem(name: "s", value: String(pixelSize))]
        return components.url
    }

    /// A hue in 0..<1 that looks random but stays the same for a login across launches,
    /// so every author keeps one color. FNV-1a, since `hashValue` is reseeded on each launch.
    public var hue: Double {
        var hash: UInt64 = 0xcbf29ce484222325
        for byte in login.lowercased().utf8 {
            hash ^= UInt64(byte)
            hash = hash &* 0x100000001b3
        }
        return Double(hash % 360) / 360
    }
}
