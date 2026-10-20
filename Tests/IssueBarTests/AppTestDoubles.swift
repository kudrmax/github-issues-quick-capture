import AppKit
@testable import IssueBar
import IssueBarCore

final class StubTracker: IssueTracker, @unchecked Sendable {
    var repositoryList: [Repository]
    var issueList: [IssueBarCore.Issue] = []
    var labelList: [IssueLabel] = []
    var details: [Int: IssueDetail] = [:]
    var issuesError: Error?
    private(set) var created: [(draft: IssueDraft, labels: [IssueLabel])] = []
    private(set) var detailRequests: [Int] = []

    init(repositories: [Repository]) {
        repositoryList = repositories
    }

    func repositories() async throws -> [Repository] { repositoryList }
    func issues(in repository: Repository) async throws -> [IssueBarCore.Issue] {
        if let issuesError { throw issuesError }
        return issueList
    }
    func labels(in repository: Repository) async throws -> [IssueLabel] { labelList }

    func issueDetail(number: Int, in repository: Repository) async throws -> IssueDetail {
        detailRequests.append(number)
        guard let detail = details[number] else { throw GHError.commandFailed("HTTP 404") }
        return detail
    }

    func createIssue(_ draft: IssueDraft, labels: [IssueLabel], in repository: Repository) async throws -> CreatedIssue {
        created.append((draft, labels))
        return CreatedIssue(url: URL(string: "https://github.com/\(repository.nameWithOwner)/issues/7")!)
    }
}

final class StubUploader: AttachmentUploader, @unchecked Sendable {
    var error: Error?
    private(set) var uploaded: [DraftImage] = []

    func upload(_ images: [DraftImage], to repository: Repository) async throws -> [URL] {
        if let error { throw error }
        uploaded += images
        return images.indices.map { URL(string: "https://img.test/\($0).png")! }
    }
}

final class StubImageLoader: IssueImageLoading, @unchecked Sendable {
    var images: [URL: Data] = [:]
    private(set) var requested: [URL] = []

    func imageData(for url: URL) async throws -> Data {
        requested.append(url)
        guard let data = images[url] else { throw ImageLoadingError.http(404) }
        return data
    }
}

final class StubSystem: SystemActions {
    private(set) var copied: [String] = []

    func copyToClipboard(_ text: String) {
        copied.append(text)
    }
}

final class InMemoryCache: RepositoryCache {
    private var repositories: [Repository]?

    func load() -> [Repository]? { repositories }
    func save(_ repositories: [Repository]) { self.repositories = repositories }
}

final class InMemoryIssueStore: IssueCache {
    private var lists: [String: [IssueBarCore.Issue]] = [:]
    private var details: [String: IssueDetail] = [:]

    func loadIssues(in repository: Repository) -> [IssueBarCore.Issue]? { lists[repository.id] }
    func saveIssues(_ issues: [IssueBarCore.Issue], in repository: Repository) { lists[repository.id] = issues }
    func loadDetail(number: Int, in repository: Repository) -> IssueDetail? { details["\(repository.id)#\(number)"] }
    func saveDetail(_ detail: IssueDetail, in repository: Repository) { details["\(repository.id)#\(detail.number)"] = detail }
}

@MainActor
func makeModel(
    tracker: StubTracker,
    uploader: StubUploader = StubUploader(),
    images: StubImageLoader = StubImageLoader(),
    issueStore: InMemoryIssueStore = InMemoryIssueStore(),
    system: StubSystem = StubSystem()
) -> IssueBarViewModel {
    IssueBarViewModel(
        tracker: tracker,
        submitter: IssueSubmitter(tracker: tracker, uploader: uploader),
        imageLoader: images,
        recents: UserDefaultsRecentRepositoriesStore(defaults: UserDefaults(suiteName: "IssueBarTests.\(UUID().uuidString)")!),
        cache: InMemoryCache(),
        issueStore: issueStore,
        system: system
    )
}

@MainActor
func eventually(_ condition: () -> Bool) async -> Bool {
    for _ in 0..<300 where !condition() {
        try? await Task.sleep(for: .milliseconds(10))
    }
    return condition()
}
