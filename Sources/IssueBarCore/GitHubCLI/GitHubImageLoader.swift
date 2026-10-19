import Foundation

public protocol IssueImageLoading: Sendable {
    func imageData(for url: URL) async throws -> Data
}

public protocol HTTPDataFetching: Sendable {
    func data(for request: URLRequest) async throws -> (Data, URLResponse)
}

extension URLSession: HTTPDataFetching {
    public func data(for request: URLRequest) async throws -> (Data, URLResponse) {
        try await data(for: request, delegate: nil)
    }
}

public enum ImageLoadingError: LocalizedError, Equatable {
    case http(Int)

    public var errorDescription: String? {
        switch self {
        case .http(let status): "Image request failed (HTTP \(status))"
        }
    }
}

/// Results go to `ImageDataCache`, so an image is downloaded once.
/// Repository files (the images IssueBar attaches) are fetched from
/// raw.githubusercontent.com with the gh token, which also works for private
/// repositories; `gh api` drops the connection on binary downloads. Any other
/// URL, including signed attachment URLs, is fetched as is.
public actor GitHubImageLoader: IssueImageLoading {
    private let gh: GHExecuting
    private let http: HTTPDataFetching
    private let cache: ImageDataCache
    private var token: String?

    public init(gh: GHExecuting, cache: ImageDataCache, http: HTTPDataFetching = GitHubImageLoader.uncachedSession) {
        self.gh = gh
        self.cache = cache
        self.http = http
    }

    /// Caching is done by `ImageDataCache` with stable keys, so the transport must not keep its own copies.
    public static let uncachedSession: URLSession = {
        let configuration = URLSessionConfiguration.ephemeral
        configuration.urlCache = nil
        configuration.requestCachePolicy = .reloadIgnoringLocalCacheData
        return URLSession(configuration: configuration)
    }()

    public func imageData(for url: URL) async throws -> Data {
        if let cached = cache.data(for: url) { return cached }
        var request: URLRequest
        if let raw = Self.rawFileURL(for: url) {
            request = URLRequest(url: raw)
            request.setValue("token \(try await authToken())", forHTTPHeaderField: "Authorization")
        } else {
            request = URLRequest(url: url)
        }
        let (data, response) = try await http.data(for: request)
        let status = (response as? HTTPURLResponse)?.statusCode ?? 0
        guard status == 200 else { throw ImageLoadingError.http(status) }
        cache.store(data, for: url)
        return data
    }

    /// `github.com/{owner}/{repo}/blob|raw/{ref}/{path}` → `raw.githubusercontent.com/{owner}/{repo}/{ref}/{path}`.
    static func rawFileURL(for url: URL) -> URL? {
        let parts = url.path.split(separator: "/").map(String.init)
        switch url.host {
        case "raw.githubusercontent.com":
            return URL(string: "https://raw.githubusercontent.com\(url.path)")
        case "github.com" where parts.count >= 5 && ["blob", "raw"].contains(parts[2]):
            let file = ([parts[0], parts[1], parts[3]] + parts[4...]).joined(separator: "/")
            return URL(string: "https://raw.githubusercontent.com/\(file)")
        default:
            return nil
        }
    }

    private func authToken() async throws -> String {
        if let token { return token }
        let output = try await gh.run(["auth", "token"])
        let value = String(decoding: output, as: UTF8.self).trimmingCharacters(in: .whitespacesAndNewlines)
        token = value
        return value
    }
}
