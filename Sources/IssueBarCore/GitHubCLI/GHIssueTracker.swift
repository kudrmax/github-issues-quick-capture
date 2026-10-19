import Foundation

public final class GHIssueTracker: IssueTracker {
    static let repositoriesEndpoint = "user/repos?per_page=100&sort=pushed&affiliation=owner,collaborator,organization_member"
    static let repositoriesFilter = """
    .[] | select(.has_issues and (.archived | not)) \
    | {nameWithOwner: .full_name, description, pushedAt: .pushed_at, isPrivate: .private}
    """
    static let issueLimit = 200
    static let labelLimit = 100

    private let gh: GHExecuting

    public init(gh: GHExecuting) {
        self.gh = gh
    }

    public func repositories() async throws -> [Repository] {
        let output = try await gh.run(["api", "--paginate", Self.repositoriesEndpoint, "--jq", Self.repositoriesFilter])
        let decoder = Self.makeDecoder()
        return try output
            .split(separator: UInt8(ascii: "\n"))
            .map { try decoder.decode(Repository.self, from: Data($0)) }
    }

    public func issues(in repository: Repository) async throws -> [Issue] {
        let output = try await gh.run([
            "issue", "list",
            "-R", repository.nameWithOwner,
            "--state", "open",
            "--limit", String(Self.issueLimit),
            "--json", "number,title,url,author,createdAt,labels",
        ])
        return try Self.makeDecoder().decode([IssueDTO].self, from: output).map(\.issue)
    }

    /// The `full` media type adds `body_html`, whose image URLs are signed for private repositories.
    public func issueDetail(number: Int, in repository: Repository) async throws -> IssueDetail {
        let output = try await gh.run([
            "api", "repos/\(repository.nameWithOwner)/issues/\(number)",
            "-H", "Accept: application/vnd.github.full+json",
        ])
        let dto = try Self.makeDecoder().decode(IssueDetailDTO.self, from: output)
        return IssueDetail(
            number: dto.number,
            title: dto.title,
            url: dto.htmlURL,
            author: dto.user?.login ?? "",
            createdAt: dto.createdAt,
            labels: dto.labels.map { IssueLabel(name: $0.name, color: $0.color ?? "808080", description: $0.description) },
            blocks: IssueBodyParser().parse(markdown: dto.body ?? "", html: dto.bodyHTML)
        )
    }

    public func labels(in repository: Repository) async throws -> [IssueLabel] {
        let output = try await gh.run([
            "label", "list",
            "-R", repository.nameWithOwner,
            "--limit", String(Self.labelLimit),
            "--json", "name,color,description",
        ])
        return try Self.makeDecoder().decode([IssueLabel].self, from: output)
    }

    public func createIssue(_ draft: IssueDraft, labels: [IssueLabel], in repository: Repository) async throws -> CreatedIssue {
        let labelArguments = labels.flatMap { ["--label", $0.name] }
        let output = try await gh.run([
            "issue", "create",
            "-R", repository.nameWithOwner,
            "--title", draft.title,
            "--body", draft.body,
        ] + labelArguments)
        let text = String(decoding: output, as: UTF8.self)
        let link = text
            .split(whereSeparator: \.isNewline)
            .map { $0.trimmingCharacters(in: .whitespaces) }
            .last { $0.hasPrefix("https://") }
        guard let link, let url = URL(string: link) else {
            throw GHError.unexpectedOutput(text)
        }
        return CreatedIssue(url: url)
    }

    private static func makeDecoder() -> JSONDecoder {
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return decoder
    }
}

private struct IssueDetailDTO: Decodable {
    struct User: Decodable { let login: String }
    struct Label: Decodable {
        let name: String
        let color: String?
        let description: String?
    }

    let number: Int
    let title: String
    let body: String?
    let bodyHTML: String?
    let htmlURL: URL
    let user: User?
    let createdAt: Date
    let labels: [Label]

    enum CodingKeys: String, CodingKey {
        case number, title, body, user, labels
        case bodyHTML = "body_html"
        case htmlURL = "html_url"
        case createdAt = "created_at"
    }
}

private struct IssueDTO: Decodable {
    struct Author: Decodable { let login: String }
    struct Label: Decodable { let name: String }

    let number: Int
    let title: String
    let url: URL
    let author: Author?
    let createdAt: Date
    let labels: [Label]

    var issue: Issue {
        Issue(
            number: number,
            title: title,
            url: url,
            author: author?.login ?? "",
            createdAt: createdAt,
            labels: labels.map(\.name)
        )
    }
}
