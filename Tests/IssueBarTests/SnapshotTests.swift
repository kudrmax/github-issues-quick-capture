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
        let tracker = StubTracker(repositories: [repository])
        tracker.labelList = [
            IssueLabel(name: "bug", color: "d73a4a"), IssueLabel(name: "enhancement", color: "a2eeef"), IssueLabel(name: "question", color: "d876e3"),
        ]
        let model = makeModel(tracker: tracker)
        model.start()
        try await waitUntil { !model.repositories.isEmpty }
        _ = model.handle(.submit)
        model.draftSegments = [
            .text("Падает импорт EPUB\nВот что вижу:\n"),
            .image(ImageEncoder.draftImage(from: .snapshotGradient(.systemRed, .systemOrange, size: NSSize(width: 900, height: 420)))!),
            .text("\nА после перезапуска так:\n"),
            .image(ImageEncoder.draftImage(from: .snapshotGradient(.systemBlue, .systemTeal, size: NSSize(width: 300, height: 160)))!),
            .text("\nКонец"),
        ]
        try await waitUntil { !model.labels.isEmpty }

        let png = try await render(RootView(model: model, cornerRadius: 14))
        #expect(png.count > 10_000)
        if let directory = ProcessInfo.processInfo.environment["ISSUEBAR_SNAPSHOT_DIR"] {
            try png.write(to: URL(fileURLWithPath: directory).appending(path: "composer-images.png"))
        }
    }

    @Test func issueListWithDetail() async throws {
        let repository = Repository(nameWithOwner: "kudrmax/anything-to-anki")
        let tracker = StubTracker(repositories: [repository])
        let titles = [
            (7, "Переработать управление с клавиатуры", ["enhancement"]),
            (6, "Вынести уровень куда-то в другое место. Сейчас он торчит", ["enhancement"]),
            (5, "Добавить отдельный вывод target", ["enhancement"]),
            (2, "Сейчас произошла каша с секцией READY", []),
        ]
        tracker.issueList = titles.map { number, title, labels in
            IssueBarCore.Issue(number: number, title: title, url: URL(string: "https://github.com/x/y/issues/\(number)")!,
                               author: number == 6 ? "ismylvdya" : "kudrmax", createdAt: Date.now.addingTimeInterval(-Double(number) * 300), labels: labels)
        }
        let screenshot = URL(string: "https://github.com/kudrmax/anything-to-anki/blob/issue-attachments/images/a.png?raw=true")!
        tracker.details[7] = IssueDetail(
            number: 7, title: "Переработать управление с клавиатуры", url: URL(string: "https://github.com/x/y/issues/7")!,
            author: "kudrmax", createdAt: Date.now.addingTimeInterval(-300),
            labels: [IssueLabel(name: "enhancement", color: "a2eeef")],
            blocks: IssueBodyParser().parse(markdown: """
            - Добавить **TTS**
            - Кнопка другие буквы переназначить
            - Добавить для других кнопок (обсудить) типа поиска картинки и т.д.

            ![image](\(screenshot.absoluteString))

            Сделать как в `Anki`, см. [доку](https://example.com).
            """)
        )
        let images = StubImageLoader()
        let picture = NSImage.snapshotGradient(.systemIndigo, .systemPink, size: NSSize(width: 1200, height: 640))
        images.images[screenshot] = NSBitmapImageRep(data: picture.tiffRepresentation!)!.representation(using: .png, properties: [:])!
        let avatar = GitHubUser(login: "kudrmax").avatarURL(pixelSize: 64)!
        images.images[avatar] = .snapshotAvatar
        let model = makeModel(tracker: tracker, images: images)
        model.start()
        try await waitUntil { !model.repositories.isEmpty }
        model.select(mode: .browse)
        _ = model.handle(.submit)
        try await waitUntil { model.issueDetail != nil }

        let png = try await render(RootView(model: model, cornerRadius: 14), size: IssueBarViewModel.widePanelSize)
        let ismylvdya = GitHubUser(login: "ismylvdya").avatarURL(pixelSize: 64)!
        #expect(Set(images.requested) == [screenshot, avatar, ismylvdya])
        #expect(images.requested.filter { $0 == avatar }.count == 1)
        if let directory = ProcessInfo.processInfo.environment["ISSUEBAR_SNAPSHOT_DIR"] {
            try png.write(to: URL(fileURLWithPath: directory).appending(path: "issue-detail.png"))
        }
    }

    @Test func repositoryPicker() async throws {
        let tracker = StubTracker(repositories: [
            Repository(nameWithOwner: "kudrmax/anything-to-anki"),
            Repository(nameWithOwner: "kudrmax/github-issues-quick-capture"),
            Repository(nameWithOwner: "ismylvdya/notes"),
        ])
        let images = StubImageLoader()
        images.images[GitHubUser(login: "kudrmax").avatarURL(pixelSize: 64)!] = .snapshotAvatar
        let model = makeModel(tracker: tracker, images: images)
        model.start()
        try await waitUntil { !model.repositories.isEmpty }

        let png = try await render(RootView(model: model, cornerRadius: 14))
        #expect(png.count > 10_000)
        if let directory = ProcessInfo.processInfo.environment["ISSUEBAR_SNAPSHOT_DIR"] {
            try png.write(to: URL(fileURLWithPath: directory).appending(path: "repository-picker.png"))
        }
    }

    private func render(_ view: some View, size: NSSize = IssueBarViewModel.compactPanelSize) async throws -> Data {
        let window = NSWindow(contentRect: NSRect(origin: .zero, size: size), styleMask: [.borderless], backing: .buffered, defer: false)
        window.appearance = NSAppearance(named: .darkAqua)
        window.backgroundColor = NSColor(white: 0.17, alpha: 1)
        let host = NSHostingView(rootView: view.background(Color(white: 0.17)).environment(\.colorScheme, .dark))
        host.frame = NSRect(origin: .zero, size: size)
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

extension NSImage {
    static func snapshotSolid(_ color: NSColor, size: NSSize) -> NSImage {
        snapshotGradient(color, color, size: size)
    }

    static func snapshotGradient(_ from: NSColor, _ to: NSColor, size: NSSize) -> NSImage {
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

extension Data {
    /// Stands in for a photo: one flat color, as a real avatar has no gradient.
    static var snapshotAvatar: Data {
        let photo = NSImage.snapshotSolid(.systemGray, size: NSSize(width: 64, height: 64))
        return NSBitmapImageRep(data: photo.tiffRepresentation!)!.representation(using: .png, properties: [:])!
    }
}
