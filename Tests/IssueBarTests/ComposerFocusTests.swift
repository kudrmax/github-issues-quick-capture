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
        let model = makeModel(tracker: StubTracker(repositories: [Repository(nameWithOwner: "me/app")]))
        let window = FloatingPanel(contentSize: IssueBarViewModel.compactPanelSize)
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
