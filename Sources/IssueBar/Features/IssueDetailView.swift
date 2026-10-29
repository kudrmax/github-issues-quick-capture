import SwiftUI
import IssueBarCore

struct IssueDetailView: View {
    let detail: IssueDetail?
    let isLoading: Bool
    let error: String?
    let loadImage: @MainActor (URL) async -> NSImage?
    let avatars: AvatarSource

    var body: some View {
        if let detail {
            ScrollView {
                VStack(alignment: .leading, spacing: 12) {
                    IssueDetailHeader(detail: detail, avatars: avatars)
                    Divider()
                    if detail.blocks.isEmpty {
                        Text("No description")
                            .font(.system(size: 14))
                            .foregroundStyle(.tertiary)
                    } else {
                        ForEach(Array(detail.blocks.enumerated()), id: \.offset) { _, block in
                            IssueBlockView(block: block, loadImage: loadImage)
                        }
                    }
                }
                .padding(20)
                .frame(maxWidth: .infinity, alignment: .leading)
                .textSelection(.enabled)
            }
            .scrollIndicators(.automatic)
        } else if let error {
            EmptyState(symbol: "exclamationmark.triangle", text: error)
        } else if isLoading {
            ProgressView().controlSize(.small).frame(maxWidth: .infinity, maxHeight: .infinity)
        } else {
            EmptyState(symbol: "text.alignleft", text: "Select an issue")
        }
    }
}

private struct IssueDetailHeader: View {
    let detail: IssueDetail
    let avatars: AvatarSource

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text(detail.title)
                .font(.system(size: 19, weight: .semibold))
                .fixedSize(horizontal: false, vertical: true)
            HStack(spacing: 6) {
                Image(systemName: "smallcircle.filled.circle")
                    .foregroundStyle(.green)
                Text("#\(detail.number)")
                    .monospacedDigit()
                if !detail.author.isEmpty {
                    Text("·")
                    HStack(spacing: 5) {
                        AuthorAvatar(user: GitHubUser(login: detail.author), source: avatars, size: 16)
                        Text(detail.author)
                    }
                }
                Text("·")
                Text(RelativeDate.string(for: detail.createdAt))
            }
            .font(.system(size: 12))
            .foregroundStyle(.secondary)
            if !detail.labels.isEmpty {
                HStack(spacing: 6) {
                    ForEach(detail.labels) { label in
                        LabelPill(label: label)
                    }
                }
            }
        }
    }
}

struct LabelPill: View {
    let label: IssueLabel

    var body: some View {
        let color = Color(hex: label.color)
        HStack(spacing: 5) {
            Circle().fill(color).frame(width: 7, height: 7)
            Text(label.name)
        }
        .font(.system(size: 11, weight: .medium))
        .padding(.horizontal, 8)
        .padding(.vertical, 3)
        .background(color.opacity(0.2), in: Capsule())
        .overlay(Capsule().strokeBorder(color.opacity(0.5), lineWidth: 1))
        .fixedSize()
    }
}

private struct IssueBlockView: View {
    let block: IssueBodyBlock
    let loadImage: @MainActor (URL) async -> NSImage?

    var body: some View {
        switch block {
        case .heading(let level, let text):
            Text(Self.inline(text))
                .font(.system(size: level == 1 ? 18 : level == 2 ? 16 : 14, weight: .semibold))
                .padding(.top, 4)
        case .paragraph(let text):
            Text(Self.inline(text))
                .font(.system(size: 14))
                .lineSpacing(2)
                .fixedSize(horizontal: false, vertical: true)
        case .listItem(let marker, let text):
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(marker)
                    .foregroundStyle(.secondary)
                    .frame(minWidth: 14, alignment: .trailing)
                Text(Self.inline(text))
                    .fixedSize(horizontal: false, vertical: true)
            }
            .font(.system(size: 14))
        case .quote(let text):
            HStack(spacing: 10) {
                RoundedRectangle(cornerRadius: 1.5)
                    .fill(Color.primary.opacity(0.2))
                    .frame(width: 3)
                Text(Self.inline(text))
                    .font(.system(size: 14))
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        case .code(let code):
            Text(code)
                .font(.system(size: 12, design: .monospaced))
                .padding(10)
                .frame(maxWidth: .infinity, alignment: .leading)
                .background(Color.primary.opacity(0.06), in: RoundedRectangle(cornerRadius: 6))
        case .image(let url):
            IssueImageView(url: url, loadImage: loadImage)
        case .rule:
            Divider()
        }
    }

    private static func inline(_ text: String) -> AttributedString {
        let options = AttributedString.MarkdownParsingOptions(interpretedSyntax: .inlineOnlyPreservingWhitespace)
        return (try? AttributedString(markdown: text, options: options)) ?? AttributedString(text)
    }
}

private struct IssueImageView: View {
    let url: URL
    let loadImage: @MainActor (URL) async -> NSImage?
    @State private var image: NSImage?
    @State private var didFail = false

    var body: some View {
        Group {
            if let image {
                Image(nsImage: image)
                    .resizable()
                    .aspectRatio(contentMode: .fit)
                    .frame(maxWidth: image.size.width)
                    .clipShape(RoundedRectangle(cornerRadius: 6))
                    .overlay(RoundedRectangle(cornerRadius: 6).strokeBorder(Color.primary.opacity(0.1)))
            } else if didFail {
                Label("Image unavailable", systemImage: "photo")
                    .font(.system(size: 12))
                    .foregroundStyle(.tertiary)
                    .help(url.absoluteString)
            } else {
                RoundedRectangle(cornerRadius: 6)
                    .fill(Color.primary.opacity(0.05))
                    .frame(height: 140)
                    .overlay(ProgressView().controlSize(.small))
            }
        }
        .task(id: url) {
            image = await loadImage(url)
            didFail = image == nil
        }
    }
}
