import SwiftUI
import IssueBarCore

struct RootView: View {
    static let issueListWidth: CGFloat = 420

    enum Field: Hashable {
        case search
    }

    @Bindable var model: IssueBarViewModel
    let cornerRadius: CGFloat
    @FocusState private var focusedField: Field?

    var body: some View {
        VStack(spacing: 0) {
            header
                .padding(.horizontal, 18)
                .frame(height: 64)
            Divider()
            content
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            FooterBar(status: footerStatus, hints: hints)
        }
        .overlay {
            if let createdIssue = model.createdIssue {
                ConfirmationView(issue: createdIssue)
                    .transition(.opacity.combined(with: .scale(scale: 0.96)))
            }
        }
        .overlay {
            RoundedRectangle(cornerRadius: cornerRadius, style: .circular)
                .strokeBorder(Color.primary.opacity(0.12), lineWidth: 1)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .animation(.easeOut(duration: 0.15), value: model.createdIssue)
        .onChange(of: model.focusRequest) { focusCurrentField() }
        .onAppear(perform: focusCurrentField)
    }

    @ViewBuilder
    private var header: some View {
        HStack(spacing: 14) {
            switch model.screen {
            case .repositoryPicker:
                SearchField(placeholder: "Search repositories", text: $model.repositoryQuery, completion: repositoryCompletion)
                    .focused($focusedField, equals: .search)
            case .composer(let repository):
                RepositoryTitle(repository: repository)
                Spacer()
            case .issueList(let repository):
                SearchField(placeholder: "Filter issues in \(repository.name)", text: $model.issueQuery)
                    .focused($focusedField, equals: .search)
            }
            ModeSwitcher(mode: model.mode, onSelect: model.select(mode:))
        }
    }

    @ViewBuilder
    private var content: some View {
        switch model.screen {
        case .repositoryPicker:
            RepositoryListView(
                sections: model.repositorySections,
                selectedIndex: model.selectedIndex,
                isLoading: model.isLoadingRepositories,
                onChoose: model.choose
            )
        case .composer:
            VStack(spacing: 0) {
                ComposerView(
                    segments: model.draftSegments,
                    resetToken: model.draftResetToken,
                    focusToken: model.focusRequest,
                    isSubmitting: model.isSubmitting,
                    onChange: { model.draftSegments = $0 }
                )
                if !model.labels.isEmpty {
                    LabelBar(labels: model.labels, selected: model.selectedLabelNames, onToggle: model.toggleLabel)
                }
            }
        case .issueList:
            HStack(spacing: 0) {
                IssueListView(
                    issues: model.visibleIssues,
                    selectedIndex: model.selectedIndex,
                    isLoading: model.isLoadingIssues,
                    hasFilter: !model.issueQuery.isEmpty,
                    onChoose: { model.choose($0) }
                )
                .frame(width: Self.issueListWidth)
                Divider()
                IssueDetailView(
                    detail: model.issueDetail,
                    isLoading: model.isLoadingDetail,
                    error: model.detailError,
                    loadImage: model.image(for:)
                )
            }
        }
    }

    private var repositoryCompletion: SearchField.Completion? {
        guard let repository = model.selectedRepository else { return nil }
        let action = model.mode == .create ? "New Issue" : "Show Issues"
        let query = model.repositoryQuery
        guard repository.name.lowercased().hasPrefix(query.lowercased()) else {
            return .init(suffix: "", action: "\(repository.name) · \(action)")
        }
        return .init(suffix: String(repository.name.dropFirst(query.count)), action: action)
    }

    private var footerStatus: FooterBar.Status? {
        if let errorMessage = model.errorMessage { return .error(errorMessage) }
        if let notice = model.notice { return .success(notice) }
        if let submissionStatus = model.submissionStatus { return .progress(submissionStatus) }
        if model.isLoadingRepositories, case .repositoryPicker = model.screen { return .progress("Refreshing…") }
        return nil
    }

    private var hints: [KeyHint] {
        switch model.screen {
        case .repositoryPicker:
            [KeyHint("↩", model.mode == .create ? "Write" : "Issues"), KeyHint("⇥", "Switch"), KeyHint("esc", "Close")]
        case .composer:
            [KeyHint("⌘↩", "Create"), KeyHint("⌘V", "Image")]
                + (model.labels.isEmpty ? [] : [KeyHint("⌘1–9", "Labels")])
                + [KeyHint("⇥", "Issues"), KeyHint("esc", "Back")]
        case .issueList:
            [KeyHint("↩", "Copy link"), KeyHint("⇥", "New"), KeyHint("esc", "Back")]
        }
    }

    private func focusCurrentField() {
        if case .composer = model.screen {
            focusedField = nil
            return
        }
        DispatchQueue.main.async { focusedField = .search }
    }
}
