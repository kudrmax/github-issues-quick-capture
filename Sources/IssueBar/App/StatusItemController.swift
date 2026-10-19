import AppKit

@MainActor
final class StatusItemController: NSObject {
    struct Actions {
        let togglePanel: () -> Void
        let refreshRepositories: () -> Void
        let clearImageCache: () -> Void
    }

    private let statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
    private let actions: Actions
    private let shortcut: GlobalHotKey.Shortcut
    private let launchAtLogin = LaunchAtLogin()
    private lazy var launchAtLoginItem = NSMenuItem(title: "Launch at Login", action: #selector(toggleLaunchAtLogin), keyEquivalent: "")

    init(shortcut: GlobalHotKey.Shortcut, actions: Actions) {
        self.shortcut = shortcut
        self.actions = actions
        super.init()
        configureButton()
    }

    private func configureButton() {
        guard let button = statusItem.button else { return }
        let image = NSImage(systemSymbolName: "smallcircle.filled.circle", accessibilityDescription: "IssueBar")
        image?.isTemplate = true
        button.image = image
        button.toolTip = "IssueBar — \(shortcut.displayString)"
        button.target = self
        button.action = #selector(buttonClicked)
        button.sendAction(on: [.leftMouseUp, .rightMouseUp])
    }

    @objc private func buttonClicked() {
        if NSApp.currentEvent?.type == .rightMouseUp {
            showMenu()
        } else {
            actions.togglePanel()
        }
    }

    private func showMenu() {
        statusItem.menu = makeMenu()
        statusItem.button?.performClick(nil)
        statusItem.menu = nil
    }

    private func makeMenu() -> NSMenu {
        let menu = NSMenu()

        let open = NSMenuItem(title: "Open", action: #selector(openPanel), keyEquivalent: shortcut.menuKeyEquivalent)
        open.keyEquivalentModifierMask = shortcut.menuModifiers
        menu.addItem(open)
        menu.addItem(NSMenuItem(title: "Refresh Repositories", action: #selector(refreshRepositories), keyEquivalent: ""))
        menu.addItem(NSMenuItem(title: "Clear Image Cache", action: #selector(clearImageCache), keyEquivalent: ""))
        menu.addItem(.separator())
        launchAtLoginItem.state = launchAtLogin.isEnabled ? .on : .off
        menu.addItem(launchAtLoginItem)
        menu.addItem(.separator())
        menu.addItem(NSMenuItem(title: "Quit IssueBar", action: #selector(quit), keyEquivalent: "q"))

        menu.items.forEach { $0.target = self }
        return menu
    }

    @objc private func openPanel() { actions.togglePanel() }

    @objc private func refreshRepositories() { actions.refreshRepositories() }

    @objc private func clearImageCache() { actions.clearImageCache() }

    @objc private func toggleLaunchAtLogin() {
        do {
            try launchAtLogin.setEnabled(!launchAtLogin.isEnabled)
        } catch {
            NSAlert(error: error).runModal()
        }
    }

    @objc private func quit() { NSApp.terminate(nil) }
}
