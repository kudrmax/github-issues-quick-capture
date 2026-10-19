import CryptoKit
import Foundation

public protocol ImageDataCache: Sendable {
    func data(for url: URL) -> Data?
    func store(_ data: Data, for url: URL)
    func removeAll()
}

/// Image URLs on GitHub never change their content: attachments are named by
/// UUID and replacing an image puts a new URL into the issue. So entries need
/// no TTL, only a size limit; `URLCache` stores them on disk and evicts the
/// least recently used when the limit is reached.
///
/// `removeAllCachedResponses()` finishes in the background, so clearing also
/// bumps a persisted generation that is part of every key: old entries stop
/// matching at once and `URLCache` deletes them from disk on its own.
public final class DiskImageCache: ImageDataCache, @unchecked Sendable {
    public static let defaultDiskCapacity = 200 * 1024 * 1024
    private static let memoryCapacity = 32 * 1024 * 1024
    private static let generationKey = "imageCacheGeneration"

    private let cache: URLCache
    private let defaults: UserDefaults
    private let lock = NSLock()

    public init(
        directory: URL = DiskImageCache.defaultDirectory,
        diskCapacity: Int = DiskImageCache.defaultDiskCapacity,
        defaults: UserDefaults = .standard
    ) {
        cache = URLCache(memoryCapacity: Self.memoryCapacity, diskCapacity: diskCapacity, directory: directory)
        self.defaults = defaults
    }

    public static var defaultDirectory: URL {
        URL.cachesDirectory.appending(path: "IssueBar", directoryHint: .isDirectory).appending(path: "Images", directoryHint: .isDirectory)
    }

    public func data(for url: URL) -> Data? {
        cache.cachedResponse(for: request(for: url))?.data
    }

    public func store(_ data: Data, for url: URL) {
        let request = request(for: url)
        let response = HTTPURLResponse(url: request.url!, statusCode: 200, httpVersion: "HTTP/1.1", headerFields: nil)!
        cache.storeCachedResponse(CachedURLResponse(response: response, data: data, storagePolicy: .allowed), for: request)
    }

    public func removeAll() {
        lock.withLock {
            defaults.set(defaults.integer(forKey: Self.generationKey) + 1, forKey: Self.generationKey)
        }
        cache.removeAllCachedResponses()
    }

    /// A synthetic URL fully under our control: the generation in the path and
    /// a hash of the normalized image URL, so nothing depends on how `URLCache`
    /// treats queries or fragments.
    private func request(for url: URL) -> URLRequest {
        let generation = lock.withLock { defaults.integer(forKey: Self.generationKey) }
        let digest = SHA256.hash(data: Data(Self.key(for: url).absoluteString.utf8))
        let hash = digest.map { String(format: "%02x", $0) }.joined()
        return URLRequest(url: URL(string: "https://image-cache.issuebar.invalid/\(generation)/\(hash)")!)
    }

    /// GitHub's image hosts put short-lived signatures (`?jwt=…`) and flags like
    /// `?raw=true` in the query; the path alone identifies the image there.
    static func key(for url: URL) -> URL {
        guard let host = url.host, Self.githubImageHosts.contains(host),
              var components = URLComponents(url: url, resolvingAgainstBaseURL: false) else { return url }
        components.query = nil
        components.fragment = nil
        return components.url ?? url
    }

    private static let githubImageHosts: Set<String> = [
        "github.com",
        "raw.githubusercontent.com",
        "private-user-images.githubusercontent.com",
        "user-images.githubusercontent.com",
        "objects.githubusercontent.com",
    ]
}
