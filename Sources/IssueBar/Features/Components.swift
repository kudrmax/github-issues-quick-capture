import SwiftUI
import IssueBarCore

enum Spotlight {
    static let searchFont = Font.system(size: 26, weight: .regular)
    static let rowFont = Font.system(size: 15, weight: .medium)
    static let detailFont = Font.system(size: 13)
    static let sectionFont = Font.system(size: 13, weight: .semibold)
    static let iconSize: CGFloat = 24
    static let selection = Color.primary.opacity(0.12)
}

struct SearchField: View {
    let placeholder: String
    @Binding var text: String
    var completion: Completion?

    /// Spotlight's inline hint after the typed text: the rest of the top hit's
    /// name highlighted, then a dash and the action.
    struct Completion {
        let suffix: String
        let action: String
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 22, weight: .regular))
                .foregroundStyle(.secondary)
            ZStack(alignment: .leading) {
                TextField(placeholder, text: $text)
                    .textFieldStyle(.plain)
                if let completion, !text.isEmpty {
                    HStack(spacing: 0) {
                        Text(text).hidden()
                        if !completion.suffix.isEmpty {
                            Text(completion.suffix)
                                .padding(.horizontal, 1)
                                .background(Color.accentColor.opacity(0.35), in: RoundedRectangle(cornerRadius: 3))
                        }
                        Text("  —  " + completion.action)
                            .font(.system(size: 20))
                            .foregroundStyle(.secondary)
                    }
                    .lineLimit(1)
                    .allowsHitTesting(false)
                }
            }
            .font(Spotlight.searchFont)
        }
    }
}

@MainActor
protocol AvatarSource {
    func loadedAvatar(for user: GitHubUser) -> NSImage?
    func avatar(for user: GitHubUser) async -> NSImage?
}

extension IssueBarViewModel: AvatarSource {}

/// The one avatar of the app, for repository owners and issue authors alike. The colored
/// monogram holds the place until the photo arrives and stays when it can't be loaded.
struct Avatar: View {
    let user: GitHubUser
    let source: AvatarSource
    var size: CGFloat = Spotlight.iconSize
    @State private var image: NSImage?

    var body: some View {
        ZStack {
            Rectangle().fill(Color(hue: user.hue, saturation: 0.55, brightness: 0.78))
            Text(user.initial)
                .font(.system(size: size * 0.5, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
            if let photo = image ?? source.loadedAvatar(for: user) {
                Image(nsImage: photo)
                    .resizable()
                    .aspectRatio(contentMode: .fill)
                    .transition(.opacity)
            }
        }
        .frame(width: size, height: size)
        .clipShape(RoundedRectangle(cornerRadius: size * 0.24, style: .continuous))
        .help(user.login)
        .task(id: user) {
            let loaded = await source.avatar(for: user)
            withAnimation(.easeOut(duration: 0.2)) { image = loaded }
        }
    }
}

struct RepositoryTitle: View {
    let repository: Repository
    let avatars: AvatarSource

    var body: some View {
        HStack(spacing: 12) {
            Avatar(user: GitHubUser(login: repository.owner), source: avatars, size: 28)
            VStack(alignment: .leading, spacing: 0) {
                Text(repository.name)
                    .font(.system(size: 17, weight: .semibold))
                Text(repository.owner)
                    .font(.system(size: 12))
                    .foregroundStyle(.secondary)
            }
            .lineLimit(1)
        }
        .fixedSize()
    }
}

struct ModeSwitcher: View {
    let mode: IssueBarViewModel.Mode
    let onSelect: (IssueBarViewModel.Mode) -> Void

    var body: some View {
        HStack(spacing: 2) {
            ForEach(IssueBarViewModel.Mode.allCases) { option in
                Text(option.title)
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(option == mode ? .primary : .secondary)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 4)
                    .background(option == mode ? Spotlight.selection : .clear, in: Capsule())
                    .contentShape(Capsule())
                    .onTapGesture { onSelect(option) }
            }
        }
        .padding(2)
        .background(Color.primary.opacity(0.05), in: Capsule())
        .fixedSize()
    }
}

struct ListSection<Item: Identifiable>: Identifiable {
    let title: String
    let items: [Item]
    var showsCount = false

    var id: String { title }
}

/// Keyboard-driven list: the view model owns the selection (an index into the
/// flattened sections), the list renders it and keeps it scrolled into view.
struct SelectableList<Item: Identifiable, Row: View>: View {
    let sections: [ListSection<Item>]
    let selectedIndex: Int
    let onChoose: (Item) -> Void
    @ViewBuilder let row: (Item) -> Row

    var body: some View {
        ScrollViewReader { proxy in
            ScrollView {
                LazyVStack(alignment: .leading, spacing: 0) {
                    ForEach(Array(zip(sections, offsets)), id: \.0.id) { section, offset in
                        SectionHeader(title: section.title, count: section.showsCount ? section.items.count : nil)
                        ForEach(Array(section.items.enumerated()), id: \.element.id) { index, item in
                            row(item)
                                .padding(.horizontal, 10)
                                .frame(height: 40)
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .background(
                                    RoundedRectangle(cornerRadius: 8, style: .continuous)
                                        .fill(offset + index == selectedIndex ? Spotlight.selection : .clear)
                                )
                                .contentShape(Rectangle())
                                .onTapGesture { onChoose(item) }
                                .id(item.id)
                        }
                    }
                }
                .padding(.horizontal, 10)
                .padding(.bottom, 8)
            }
            .scrollIndicators(.never)
            .onChange(of: selectedIndex) { _, index in
                let items = sections.flatMap(\.items)
                guard items.indices.contains(index) else { return }
                proxy.scrollTo(items[index].id)
            }
        }
    }

    private var offsets: [Int] {
        var running = 0
        return sections.map { section in
            defer { running += section.items.count }
            return running
        }
    }
}

private struct SectionHeader: View {
    let title: String
    let count: Int?

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 6) {
                Text(title)
                if let count {
                    Text("\(count)")
                        .monospacedDigit()
                        .badge()
                }
            }
            .font(Spotlight.sectionFont)
            .foregroundStyle(.secondary)
            Divider()
        }
        .padding(.horizontal, 8)
        .padding(.top, 12)
        .padding(.bottom, 6)
    }
}

struct IssueNumberBadge: View {
    let number: Int

    var body: some View {
        Text("#\(number)")
            .monospacedDigit()
            .badge()
    }
}

extension View {
    /// The app's one badge: key hints, issue numbers and counts.
    func badge() -> some View {
        padding(.horizontal, 5)
            .padding(.vertical, 1.5)
            .background(Color.primary.opacity(0.08), in: RoundedRectangle(cornerRadius: 4))
    }
}

struct EmptyState: View {
    let symbol: String
    let text: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: symbol)
                .font(.system(size: 26))
            Text(text)
                .font(.system(size: 13))
        }
        .foregroundStyle(.tertiary)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

struct KeyHint: Identifiable {
    let key: String
    let label: String

    init(_ key: String, _ label: String) {
        self.key = key
        self.label = label
    }

    var id: String { key }
}

struct FooterBar: View {
    enum Status {
        case progress(String)
        case success(String)
        case error(String)
    }

    let status: Status?
    let hints: [KeyHint]

    var body: some View {
        HStack(spacing: 14) {
            statusView
            Spacer(minLength: 12)
            ForEach(hints) { hint in
                HStack(spacing: 5) {
                    Text(hint.key)
                        .font(.system(size: 10, weight: .semibold, design: .rounded))
                        .badge()
                    Text(hint.label)
                }
            }
        }
        .font(.system(size: 11))
        .foregroundStyle(.tertiary)
        .padding(.horizontal, 16)
        .frame(height: 30)
    }

    @ViewBuilder
    private var statusView: some View {
        switch status {
        case .progress(let text):
            HStack(spacing: 6) {
                ProgressView().controlSize(.mini)
                Text(text)
            }
            .foregroundStyle(.secondary)
        case .success(let text):
            Label(text, systemImage: "checkmark.circle.fill")
                .foregroundStyle(.green)
        case .error(let text):
            Label(text, systemImage: "exclamationmark.triangle.fill")
                .foregroundStyle(.red)
                .lineLimit(1)
                .truncationMode(.tail)
                .help(text)
        case nil:
            EmptyView()
        }
    }
}

struct ConfirmationView: View {
    let issue: CreatedIssue

    var body: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.circle.fill")
                .font(.system(size: 46))
                .foregroundStyle(.green)
            Text(issue.number.map { "Issue #\($0) created" } ?? "Issue created")
                .font(.system(size: 17, weight: .semibold))
            Text("Link copied to clipboard")
                .font(.system(size: 13))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .background(.regularMaterial)
    }
}

@MainActor
enum RelativeDate {
    private static let formatter: RelativeDateTimeFormatter = {
        let formatter = RelativeDateTimeFormatter()
        formatter.locale = Locale(identifier: "en_US")
        formatter.unitsStyle = .abbreviated
        return formatter
    }()

    static func string(for date: Date) -> String {
        formatter.localizedString(for: date, relativeTo: .now)
    }
}
