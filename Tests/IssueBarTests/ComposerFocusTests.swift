import AppKit
import SwiftUI
import Testing
@testable import IssueBar
import IssueBarCore

/// Hosts the real panel content in a window that is never ordered on screen.
@MainActor
struct ComposerFocusTests {
    @Test func composerTextViewBecomesFirstResponder() async throws {
        let (model, window) = try await makePanel()
        _ = model.handle(.submit)
        try await settle(window)

        let responder = window.firstResponder
        #expect(responder is ComposerTextView, "first responder is \(String(describing: responder))")
    }

    @Test func pasteActionReachesTheEditorThroughTheResponderChain() async throws {
        let (model, window) = try await makePanel()
        _ = model.handle(.submit)
        try await settle(window)
        let textView = try #require(window.firstResponder as? ComposerTextView)
        let pasteboard = NSPasteboard(name: NSPasteboard.Name("IssueBarFocus.\(UUID().uuidString)"))
        textView.pasteboard = pasteboard
        pasteboard.clearContents()
        pasteboard.writeObjects([NSImage.sample(color: .systemRed)])

        let handled = window.firstResponder?.tryToPerform(#selector(NSText.paste(_:)), with: nil)
        try await settle(window)

        #expect(handled == true)
        #expect(model.draftSegments.contains { if case .image = $0 { true } else { false } })
    }

    @Test func editHasPasteBoundToCommandV() throws {
        let edit = try #require(MainMenu.make().items.first?.submenu)
        let paste = try #require(edit.items.first { $0.action == #selector(NSText.paste(_:)) })
        #expect(paste.keyEquivalent == "v")
        #expect(paste.keyEquivalentModifierMask == .command)
    }

    private func makePanel() async throws -> (IssueBarViewModel, NSWindow) {
        let repository = Repository(nameWithOwner: "me/app")
        let tracker = FocusTracker(repository: repository)
        let model = IssueBarViewModel(
            tracker: tracker,
            submitter: IssueSubmitter(tracker: tracker, uploader: FocusUploader()),
            recents: UserDefaultsRecentRepositoriesStore(defaults: UserDefaults(suiteName: "IssueBarFocus.\(UUID())")!),
            cache: FocusCache(),
            system: FocusSystem()
        )
        let window = FloatingPanel(contentSize: RootView.size)
        window.contentView = NSHostingView(rootView: RootView(model: model, cornerRadius: 14))
        model.start()
        for _ in 0..<200 where model.repositories.isEmpty {
            try await Task.sleep(for: .milliseconds(10))
        }
        model.panelDidOpen()
        try await settle(window)
        return (model, window)
    }

    private func settle(_ window: NSWindow) async throws {
        for _ in 0..<5 {
            window.contentView?.layoutSubtreeIfNeeded()
            try await Task.sleep(for: .milliseconds(60))
        }
    }
}

private final class FocusTracker: IssueTracker, @unchecked Sendable {
    let repository: Repository
    init(repository: Repository) { self.repository = repository }
    func repositories() async throws -> [Repository] { [repository] }
    func issues(in repository: Repository) async throws -> [IssueBarCore.Issue] { [] }
    func labels(in repository: Repository) async throws -> [IssueLabel] { [] }
    func createIssue(_ draft: IssueDraft, labels: [IssueLabel], in repository: Repository) async throws -> CreatedIssue {
        CreatedIssue(url: URL(string: "https://github.com/x/y/issues/1")!)
    }
}

private final class FocusUploader: AttachmentUploader, @unchecked Sendable {
    func upload(_ images: [DraftImage], to repository: Repository) async throws -> [URL] { [] }
}

private final class FocusSystem: SystemActions {
    func copyToClipboard(_ text: String) {}
}

private final class FocusCache: RepositoryCache {
    func load() -> [Repository]? { nil }
    func save(_ repositories: [Repository]) {}
}
