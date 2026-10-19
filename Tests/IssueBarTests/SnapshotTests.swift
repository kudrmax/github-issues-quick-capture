import AppKit
import SwiftUI
import Testing
@testable import IssueBar
import IssueBarCore

/// Renders the real panel content into an off-screen buffer. The window is never
/// ordered on screen, so it takes no focus. Set ISSUEBAR_SNAPSHOT_DIR to keep the PNGs.
@MainActor
struct SnapshotTests {
    @Test func composerWithInlineImages() async throws {
        let repository = Repository(nameWithOwner: "kudrmax/anything-to-anki")
        let tracker = SnapshotTracker(repository: repository)
        let model = IssueBarViewModel(
            tracker: tracker,
            submitter: IssueSubmitter(tracker: tracker, uploader: SnapshotUploader()),
            recents: UserDefaultsRecentRepositoriesStore(defaults: UserDefaults(suiteName: "IssueBarSnapshots.\(UUID())")!),
            cache: SnapshotCache(),
            system: SnapshotSystem()
        )
        model.start()
        try await waitUntil { !model.repositories.isEmpty }
        _ = model.handle(.submit)
        model.draftSegments = [
            .text("Падает импорт EPUB\nВот что вижу:\n"),
            .image(ImageEncoder.draftImage(from: .gradient(.systemRed, .systemOrange, size: NSSize(width: 900, height: 420)))!),
            .text("\nА после перезапуска так:\n"),
            .image(ImageEncoder.draftImage(from: .gradient(.systemBlue, .systemTeal, size: NSSize(width: 300, height: 160)))!),
            .text("\nКонец"),
        ]
        try await waitUntil { !model.labels.isEmpty }

        let png = try await render(RootView(model: model, cornerRadius: 14))
        #expect(png.count > 10_000)
        if let directory = ProcessInfo.processInfo.environment["ISSUEBAR_SNAPSHOT_DIR"] {
            try png.write(to: URL(fileURLWithPath: directory).appending(path: "composer-images.png"))
        }
    }

    private func render(_ view: some View) async throws -> Data {
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: RootView.size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = NSColor(white: 0.17, alpha: 1)
        let host = NSHostingView(rootView: view.background(Color(white: 0.17)).environment(\.colorScheme, .dark))
        host.frame = NSRect(origin: .zero, size: RootView.size)
        window.contentView = host
        for _ in 0..<5 {
            host.layoutSubtreeIfNeeded()
            try await Task.sleep(for: .milliseconds(100))
        }
        let bitmap = try #require(host.bitmapImageRepForCachingDisplay(in: host.bounds))
        host.cacheDisplay(in: host.bounds, to: bitmap)
        return try #require(bitmap.representation(using: .png, properties: [:]))
    }

    private func waitUntil(_ condition: () -> Bool) async throws {
        for _ in 0..<200 where !condition() {
            try await Task.sleep(for: .milliseconds(10))
        }
        try #require(condition())
    }
}

private extension NSImage {
    static func gradient(_ from: NSColor, _ to: NSColor, size: NSSize) -> NSImage {
        let bitmap = NSBitmapImageRep(
            bitmapDataPlanes: nil, pixelsWide: Int(size.width), pixelsHigh: Int(size.height),
            bitsPerSample: 8, samplesPerPixel: 4, hasAlpha: true, isPlanar: false,
            colorSpaceName: .deviceRGB, bytesPerRow: 0, bitsPerPixel: 0
        )!
        NSGraphicsContext.saveGraphicsState()
        NSGraphicsContext.current = NSGraphicsContext(bitmapImageRep: bitmap)
        NSGradient(starting: from, ending: to)?.draw(in: NSRect(origin: .zero, size: size), angle: 30)
        NSGraphicsContext.restoreGraphicsState()
        let image = NSImage(size: size)
        image.addRepresentation(bitmap)
        return image
    }
}

private final class SnapshotTracker: IssueTracker, @unchecked Sendable {
    let repository: Repository
    init(repository: Repository) { self.repository = repository }
    func repositories() async throws -> [Repository] { [repository] }
    func issues(in repository: Repository) async throws -> [IssueBarCore.Issue] { [] }
    func labels(in repository: Repository) async throws -> [IssueLabel] {
        [IssueLabel(name: "bug", color: "d73a4a"), IssueLabel(name: "enhancement", color: "a2eeef"), IssueLabel(name: "question", color: "d876e3")]
    }
    func createIssue(_ draft: IssueDraft, labels: [IssueLabel], in repository: Repository) async throws -> CreatedIssue {
        CreatedIssue(url: URL(string: "https://github.com/x/y/issues/1")!)
    }
}

private final class SnapshotUploader: AttachmentUploader, @unchecked Sendable {
    func upload(_ images: [DraftImage], to repository: Repository) async throws -> [URL] { [] }
}

private final class SnapshotSystem: SystemActions {
    func copyToClipboard(_ text: String) {}
}

private final class SnapshotCache: RepositoryCache {
    func load() -> [Repository]? { nil }
    func save(_ repositories: [Repository]) {}
}
