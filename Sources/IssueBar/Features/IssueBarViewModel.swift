import AppKit
import Observation
import IssueBarCore

@MainActor
@Observable
final class IssueBarViewModel {
    enum Mode: CaseIterable, Identifiable {
        case create
        case browse

        var id: Self { self }

        var title: String {
            switch self {
            case .create: "New"
            case .browse: "Issues"
            }
        }

        var toggled: Mode { self == .create ? .browse : .create }
    }

    enum Screen: Equatable {
        case repositoryPicker
        case composer(Repository)
        case issueList(Repository)
    }

    static let compactPanelSize = NSSize(width: 680, height: 440)
    static let widePanelSize = NSSize(width: 1080, height: 620)

    private static let repositoryRefreshInterval: TimeInterval = 300
    private static let detailDebounce: Duration = .milliseconds(120)
    private static let confirmationDuration: Duration = .milliseconds(1100)
    private static let noticeDuration: Duration = .milliseconds(1500)

    private(set) var mode: Mode = .create
    private(set) var screen: Screen = .repositoryPicker
    private(set) var repositories: [Repository] = []
    private(set) var issues: [Issue] = []
    private(set) var selectedIndex = 0
    private(set) var isLoadingRepositories = false
    private(set) var isLoadingIssues = false
    private(set) var isSubmitting = false
    private(set) var submissionStatus: String?
    private(set) var errorMessage: String?
    private(set) var createdIssue: CreatedIssue?
    private(set) var notice: String?
    private(set) var labels: [IssueLabel] = []
    private(set) var issueDetail: IssueDetail?
    private(set) var isLoadingDetail = false
    private(set) var detailError: String?
    private(set) var selectedLabelNames: Set<String> = []
    private(set) var focusRequest = 0
    private(set) var draftResetToken = 0

    var repositoryQuery = "" { didSet { selectedIndex = 0 } }
    var issueQuery = "" {
        didSet {
            selectedIndex = 0
            scheduleDetailLoad()
        }
    }
    var draftSegments: [DraftSegment] = []

    @ObservationIgnored var onDismiss: () -> Void = {}
    @ObservationIgnored var onPanelSizeChange: (NSSize) -> Void = { _ in }

    @ObservationIgnored private let tracker: IssueTracker
    @ObservationIgnored private let submitter: IssueSubmitter
    @ObservationIgnored private let imageLoader: IssueImageLoading
    @ObservationIgnored private let detailStore: IssueDetailCache
    @ObservationIgnored private var detailCache: [String: IssueDetail] = [:]
    @ObservationIgnored private var detailTask: Task<Void, Never>?
    @ObservationIgnored private let recents: RecentRepositoriesStore
    @ObservationIgnored private let cache: RepositoryCache
    @ObservationIgnored private let system: SystemActions
    @ObservationIgnored private let ranker = RepositoryRanker()
    @ObservationIgnored private let issueFilter = IssueFilter()
    @ObservationIgnored private var lastRepositoryRefresh: Date?
    @ObservationIgnored private var issuesRepository: Repository?
    @ObservationIgnored private var labelsRepository: Repository?
    @ObservationIgnored private var labelCache: [String: [IssueLabel]] = [:]
    private var lastUsed: [String: Date]

    init(
        tracker: IssueTracker,
        submitter: IssueSubmitter,
        imageLoader: IssueImageLoading,
        recents: RecentRepositoriesStore,
        cache: RepositoryCache,
        detailStore: IssueDetailCache,
        system: SystemActions
    ) {
        self.tracker = tracker
        self.submitter = submitter
        self.imageLoader = imageLoader
        self.recents = recents
        self.cache = cache
        self.detailStore = detailStore
        self.system = system
        self.lastUsed = recents.lastUsedDates()
    }

    private static let recentSectionLimit = 5

    var visibleRepositories: [Repository] {
        ranker.rank(repositories, query: repositoryQuery, lastUsed: lastUsed)
    }

    /// Spotlight-like grouping. Flattened, the sections keep the order of
    /// `visibleRepositories`, so `selectedIndex` stays valid across them.
    var repositorySections: [ListSection<Repository>] {
        let ranked = visibleRepositories
        if !repositoryQuery.isEmpty {
            return [
                ListSection(title: "Top Hit", items: Array(ranked.prefix(1))),
                ListSection(title: "Repositories", items: Array(ranked.dropFirst())),
            ].filter { !$0.items.isEmpty }
        }
        let recentCount = min(ranked.prefix { lastUsed[$0.id] != nil }.count, Self.recentSectionLimit)
        return [
            ListSection(title: "Recent", items: Array(ranked.prefix(recentCount))),
            ListSection(title: "All Repositories", items: Array(ranked.dropFirst(recentCount))),
        ].filter { !$0.items.isEmpty }
    }

    var selectedRepository: Repository? {
        let ranked = visibleRepositories
        return ranked.indices.contains(selectedIndex) ? ranked[selectedIndex] : nil
    }

    var visibleIssues: [Issue] {
        issueFilter.filter(issues, query: issueQuery)
    }

    var selectedIssue: Issue? {
        let visible = visibleIssues
        return visible.indices.contains(selectedIndex) ? visible[selectedIndex] : nil
    }

    var panelSize: NSSize {
        if case .issueList = screen { Self.widePanelSize } else { Self.compactPanelSize }
    }

    // MARK: Lifecycle

    func start() {
        if let cached = cache.load() {
            repositories = cached
        }
        refreshRepositories()
    }

    func panelWillOpen() {
        errorMessage = nil
        let isStale = lastRepositoryRefresh.map { Date.now.timeIntervalSince($0) > Self.repositoryRefreshInterval } ?? true
        if isStale {
            refreshRepositories()
        }
        if case .issueList(let repository) = screen {
            loadIssues(for: repository)
        }
    }

    func panelDidOpen() {
        focusRequest += 1
    }

    // MARK: Input

    func handle(_ command: KeyCommand) -> Bool {
        guard createdIssue == nil else { return true }
        switch command {
        case .moveUp: return moveSelection(by: -1)
        case .moveDown: return moveSelection(by: 1)
        case .moveLeft:
            guard case .issueList = screen else { return false }
            show(.repositoryPicker)
        case .moveRight:
            guard case .repositoryPicker = screen else { return false }
            submit()
        case .submit:
            if case .composer = screen { return false }
            submit()
        case .commandSubmit: submit()
        case .back: back()
        case .switchMode: select(mode: mode.toggled)
        case .close: onDismiss()
        case .quit: return false
        case .toggleLabel(let index): toggleLabel(at: index)
        }
        return true
    }

    func select(mode newMode: Mode) {
        guard newMode != mode else { return }
        mode = newMode
        switch screen {
        case .repositoryPicker:
            focusRequest += 1
        case .composer(let repository):
            show(.issueList(repository))
        case .issueList(let repository):
            show(.composer(repository))
        }
    }

    func choose(_ repository: Repository) {
        let now = Date.now
        lastUsed[repository.id] = now
        recents.markUsed(repository.id, at: now)
        show(mode == .create ? .composer(repository) : .issueList(repository))
    }

    func toggleLabel(_ label: IssueLabel) {
        if selectedLabelNames.contains(label.name) {
            selectedLabelNames.remove(label.name)
        } else {
            selectedLabelNames.insert(label.name)
        }
    }

    /// A click both shows the issue and copies its link.
    func choose(_ issue: Issue) {
        guard let index = visibleIssues.firstIndex(of: issue) else { return }
        selectedIndex = index
        scheduleDetailLoad()
        copyLink(to: issue)
    }

    func image(for url: URL) async -> NSImage? {
        guard let data = try? await imageLoader.imageData(for: url) else { return nil }
        return NSImage(data: data)
    }

    func copyLink(to issue: Issue) {
        system.copyToClipboard(issue.url.absoluteString)
        let message = "Copied link to #\(issue.number)"
        notice = message
        Task {
            try? await Task.sleep(for: Self.noticeDuration)
            if notice == message { notice = nil }
        }
    }

    func refreshRepositories() {
        guard !isLoadingRepositories else { return }
        isLoadingRepositories = true
        Task {
            defer { isLoadingRepositories = false }
            do {
                let fetched = try await tracker.repositories()
                repositories = fetched
                lastRepositoryRefresh = .now
                cache.save(fetched)
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    // MARK: Private

    private func moveSelection(by delta: Int) -> Bool {
        let count: Int
        switch screen {
        case .repositoryPicker: count = visibleRepositories.count
        case .issueList: count = visibleIssues.count
        case .composer: return false
        }
        guard count > 0 else { return true }
        selectedIndex = min(max(selectedIndex + delta, 0), count - 1)
        if case .issueList = screen { scheduleDetailLoad() }
        return true
    }

    private func submit() {
        switch screen {
        case .repositoryPicker:
            let candidates = visibleRepositories
            guard candidates.indices.contains(selectedIndex) else { return }
            choose(candidates[selectedIndex])
        case .composer(let repository):
            createIssue(in: repository)
        case .issueList:
            let candidates = visibleIssues
            guard candidates.indices.contains(selectedIndex) else { return }
            copyLink(to: candidates[selectedIndex])
        }
    }

    private func back() {
        switch screen {
        case .repositoryPicker:
            if repositoryQuery.isEmpty {
                onDismiss()
            } else {
                repositoryQuery = ""
            }
        case .composer, .issueList:
            show(.repositoryPicker)
        }
    }

    private func show(_ newScreen: Screen) {
        let previousSize = panelSize
        screen = newScreen
        if panelSize != previousSize { onPanelSizeChange(panelSize) }
        selectedIndex = 0
        errorMessage = nil
        focusRequest += 1
        switch newScreen {
        case .issueList(let repository):
            issueQuery = ""
            loadIssues(for: repository)
        case .composer(let repository):
            loadLabels(for: repository)
        case .repositoryPicker:
            break
        }
    }

    private func toggleLabel(at index: Int) {
        guard case .composer = screen, labels.indices.contains(index) else { return }
        toggleLabel(labels[index])
    }

    private func loadLabels(for repository: Repository) {
        if labelsRepository != repository {
            labelsRepository = repository
            selectedLabelNames = []
            labels = labelCache[repository.id] ?? []
        }
        Task {
            guard let loaded = try? await tracker.labels(in: repository) else { return }
            labelCache[repository.id] = loaded
            guard labelsRepository == repository else { return }
            labels = loaded
            selectedLabelNames.formIntersection(loaded.map(\.name))
        }
    }

    private func loadIssues(for repository: Repository) {
        if issuesRepository != repository {
            issues = []
            issuesRepository = repository
        }
        isLoadingIssues = true
        Task {
            defer { isLoadingIssues = false }
            do {
                let loaded = try await tracker.issues(in: repository)
                guard issuesRepository == repository else { return }
                issues = loaded
                scheduleDetailLoad()
            } catch {
                guard issuesRepository == repository else { return }
                errorMessage = error.localizedDescription
            }
        }
    }

    /// Content is cached per issue in memory and on disk and stays valid while
    /// the issue's `updatedAt` from the freshly loaded list matches; a newer one
    /// triggers a reload while the cached version stays on screen.
    private func scheduleDetailLoad() {
        detailTask?.cancel()
        guard case .issueList(let repository) = screen, let issue = selectedIssue else {
            issueDetail = nil
            return
        }
        let key = "\(repository.id)#\(issue.number)"
        detailError = nil
        if let cached = cachedDetail(number: issue.number, in: repository, key: key) {
            issueDetail = cached
            if cached.updatedAt >= issue.updatedAt {
                isLoadingDetail = false
                return
            }
        } else if issueDetail?.number != issue.number {
            issueDetail = nil
        }
        isLoadingDetail = true
        detailTask = Task {
            try? await Task.sleep(for: Self.detailDebounce)
            guard !Task.isCancelled else { return }
            do {
                let detail = try await tracker.issueDetail(number: issue.number, in: repository)
                detailCache[key] = detail
                detailStore.save(detail, in: repository)
                guard !Task.isCancelled else { return }
                issueDetail = detail
            } catch {
                guard !Task.isCancelled else { return }
                detailError = error.localizedDescription
            }
            isLoadingDetail = false
        }
    }

    private func cachedDetail(number: Int, in repository: Repository, key: String) -> IssueDetail? {
        if let cached = detailCache[key] { return cached }
        let stored = detailStore.load(number: number, in: repository)
        detailCache[key] = stored
        return stored
    }

    private func createIssue(in repository: Repository) {
        let document = DraftDocument(segments: draftSegments)
        guard !isSubmitting, !document.isEmpty else { return }
        guard document.canBecomeIssue else {
            errorMessage = IssueSubmissionError.missingTitle.localizedDescription
            return
        }
        let imageCount = document.images.count
        isSubmitting = true
        submissionStatus = imageCount == 0 ? "Creating issue…" : "Uploading \(imageCount == 1 ? "image" : "\(imageCount) images")…"
        errorMessage = nil
        Task {
            defer {
                isSubmitting = false
                submissionStatus = nil
            }
            do {
                let chosenLabels = labels.filter { selectedLabelNames.contains($0.name) }
                let created = try await submitter.submit(document, labels: chosenLabels, to: repository)
                system.copyToClipboard(created.url.absoluteString)
                draftSegments = []
                draftResetToken += 1
                selectedLabelNames = []
                createdIssue = created
                try? await Task.sleep(for: Self.confirmationDuration)
                finishAfterCreation()
            } catch {
                errorMessage = error.localizedDescription
            }
        }
    }

    private func finishAfterCreation() {
        createdIssue = nil
        repositoryQuery = ""
        show(.repositoryPicker)
        onDismiss()
    }
}
