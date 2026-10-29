import SwiftUI
import IssueBarCore

struct IssueListView: View {
    let issues: [Issue]
    let selectedIndex: Int
    let isLoading: Bool
    let hasFilter: Bool
    let avatars: AvatarSource
    let onChoose: (Issue) -> Void

    var body: some View {
        if issues.isEmpty {
            if isLoading {
                ProgressView().controlSize(.small).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                EmptyState(
                    symbol: hasFilter ? "magnifyingglass" : "checkmark.circle",
                    text: hasFilter ? "No matching issues" : "No open issues"
                )
            }
        } else {
            SelectableList(
                sections: [ListSection(title: "Open Issues · \(issues.count)", items: issues)],
                selectedIndex: selectedIndex,
                onChoose: onChoose
            ) { issue in
                IssueRow(issue: issue, avatars: avatars)
            }
        }
    }
}

private struct IssueRow: View {
    let issue: Issue
    let avatars: AvatarSource

    var body: some View {
        HStack(spacing: 10) {
            AuthorAvatar(user: GitHubUser(login: issue.author), source: avatars)
            Text(issue.title)
                .font(Spotlight.rowFont)
                .truncationMode(.tail)
            Spacer(minLength: 8)
            Text("#\(issue.number) · \(RelativeDate.string(for: issue.createdAt))")
                .font(Spotlight.detailFont.monospacedDigit())
                .foregroundStyle(.tertiary)
                .fixedSize()
        }
        .lineLimit(1)
    }
}
