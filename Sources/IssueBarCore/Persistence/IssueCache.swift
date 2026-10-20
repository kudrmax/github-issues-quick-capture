import Foundation

/// Keeps issue lists and issue content between launches, so both appear
/// instantly while fresh data loads. Freshness of content is decided by the
/// caller against `updatedAt` from the issue list.
public protocol IssueCache: AnyObject {
    func loadIssues(in repository: Repository) -> [Issue]?
    func saveIssues(_ issues: [Issue], in repository: Repository)
    func loadDetail(number: Int, in repository: Repository) -> IssueDetail?
    func saveDetail(_ detail: IssueDetail, in repository: Repository)
}

public final class FileIssueCache: IssueCache {
    private let directory: URL

    public init(directory: URL = FileIssueCache.defaultDirectory) {
        self.directory = directory
    }

    public static var defaultDirectory: URL {
        URL.cachesDirectory
            .appending(path: "IssueBar", directoryHint: .isDirectory)
            .appending(path: "Issues", directoryHint: .isDirectory)
    }

    public func loadIssues(in repository: Repository) -> [Issue]? {
        read([Issue].self, from: fileURL("list.json", in: repository))
    }

    public func saveIssues(_ issues: [Issue], in repository: Repository) {
        write(issues, to: fileURL("list.json", in: repository))
    }

    public func loadDetail(number: Int, in repository: Repository) -> IssueDetail? {
        read(IssueDetail.self, from: fileURL("\(number).json", in: repository))
    }

    public func saveDetail(_ detail: IssueDetail, in repository: Repository) {
        write(detail, to: fileURL("\(detail.number).json", in: repository))
    }

    private func read<Value: Decodable>(_ type: Value.Type, from url: URL) -> Value? {
        guard let data = try? Data(contentsOf: url) else { return nil }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try? decoder.decode(type, from: data)
    }

    private func write(_ value: some Encodable, to url: URL) {
        let encoder = JSONEncoder()
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(value) else { return }
        try? FileManager.default.createDirectory(at: url.deletingLastPathComponent(), withIntermediateDirectories: true)
        try? data.write(to: url, options: .atomic)
    }

    private func fileURL(_ name: String, in repository: Repository) -> URL {
        directory
            .appending(path: repository.owner, directoryHint: .isDirectory)
            .appending(path: repository.name, directoryHint: .isDirectory)
            .appending(path: name)
    }
}
