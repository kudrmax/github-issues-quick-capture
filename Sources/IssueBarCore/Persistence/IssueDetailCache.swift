import Foundation

/// Keeps issue content between launches. Freshness is decided by the caller
/// against `updatedAt` from the issue list.
public protocol IssueDetailCache: AnyObject {
    func load(number: Int, in repository: Repository) -> IssueDetail?
    func save(_ detail: IssueDetail, in repository: Repository)
}

public final class FileIssueDetailCache: IssueDetailCache {
    private let directory: URL

    public init(directory: URL = FileIssueDetailCache.defaultDirectory) {
        self.directory = directory
    }

    public static var defaultDirectory: URL {
        URL.cachesDirectory
            .appending(path: "IssueBar", directoryHint: .isDirectory)
            .appending(path: "Issues", directoryHint: .isDirectory)
    }

    public func load(number: Int, in repository: Repository) -> IssueDetail? {
        guard let data = try? Data(contentsOf: fileURL(number: number, in: repository)) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(IssueDetail.self, from: data)
    }

    public func save(_ detail: IssueDetail, in repository: Repository) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(detail) else { return }
        let url = fileURL(number: detail.number, in: repository)
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }

    private func fileURL(number: Int, in repository: Repository) -> URL {
        directory
            .appending(path: repository.owner, directoryHint: .isDirectory)
            .appending(path: repository.name, directoryHint: .isDirectory)
            .appending(path: "\(number).json")
    }
}
