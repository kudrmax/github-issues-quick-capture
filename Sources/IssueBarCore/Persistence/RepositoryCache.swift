import Foundation

/// Keeps the last fetched repository list so the picker is filled instantly on launch.
public protocol RepositoryCache: AnyObject {
    func load() -> [Repository]?
    func save(_ repositories: [Repository])
}

public final class FileRepositoryCache: RepositoryCache {
    private let fileURL: URL

    public init(fileURL: URL = FileRepositoryCache.defaultFileURL) {
        self.fileURL = fileURL
    }

    public static var defaultFileURL: URL {
        URL.applicationSupportDirectory
            .appending(path: "IssueBar", directoryHint: .isDirectory)
            .appending(path: "repositories.json")
    }

    public func load() -> [Repository]? {
        guard let data = try? Data(contentsOf: fileURL) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode([Repository].self, from: data)
    }

    public func save(_ repositories: [Repository]) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(repositories) else { return }
        try? FileManager.default.createDirectory(at: fileURL.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: fileURL, options: .atomic)
    }
}
