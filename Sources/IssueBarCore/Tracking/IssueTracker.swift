public protocol IssueTracker: Sendable {
    func repositories() async throws -> [Repository]
    func issues(in repository: Repository) async throws -> [Issue]
    func labels(in repository: Repository) async throws -> [IssueLabel]
    func createIssue(_ draft: IssueDraft, labels: [IssueLabel], in repository: Repository) async throws -> CreatedIssue
}
