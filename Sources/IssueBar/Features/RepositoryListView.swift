import SwiftUI
import IssueBarCore

struct RepositoryListView: View {
    let sections: [ListSection<Repository>]
    let selectedIndex: Int
    let isLoading: Bool
    let avatars: AvatarSource
    let onChoose: (Repository) -> Void

    var body: some View {
        if sections.isEmpty {
            if isLoading {
                ProgressView().controlSize(.small).frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                EmptyState(symbol: "magnifyingglass", text: "No repositories found")
            }
        } else {
            SelectableList(sections: sections, selectedIndex: selectedIndex, onChoose: onChoose) { repository in
                RepositoryRow(repository: repository, avatars: avatars)
            }
        }
    }
}

private struct RepositoryRow: View {
    let repository: Repository
    let avatars: AvatarSource

    var body: some View {
        HStack(spacing: 10) {
            Avatar(user: GitHubUser(login: repository.owner), source: avatars)
            Text(repository.name)
                .font(Spotlight.rowFont)
            if repository.isPrivate {
                Image(systemName: "lock.fill")
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
            }
            Text(repository.owner)
                .font(Spotlight.detailFont)
                .foregroundStyle(.secondary)
            Spacer(minLength: 8)
            if let pushedAt = repository.pushedAt {
                Text(RelativeDate.string(for: pushedAt))
                    .font(Spotlight.detailFont)
                    .foregroundStyle(.tertiary)
            }
        }
        .lineLimit(1)
    }
}
