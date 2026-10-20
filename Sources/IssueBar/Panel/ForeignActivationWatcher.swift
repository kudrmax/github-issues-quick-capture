import AppKit

/// Reports when another app takes focus the way Spotlight reacts to it: a click
/// on another window or the desktop, or ⌘⇥. Overlay tools such as clipboard
/// managers also activate their app, but show a window above normal ones,
/// so their activation is ignored and the panel stays open for pasting.
@MainActor
final class ForeignActivationWatcher {
    private static let overlayAppearanceDelay: Duration = .milliseconds(250)
    private static let menuBarStripHeight: CGFloat = 50

    private let onForeignActivation: () -> Void
    private var observer: NSObjectProtocol?
    private var pendingCheck: Task<Void, Never>?

    init(onForeignActivation: @escaping () -> Void) {
        self.onForeignActivation = onForeignActivation
    }

    func start() {
        guard observer == nil else { return }
        observer = NSWorkspace.shared.notificationCenter.addObserver(
            forName: NSWorkspace.didActivateApplicationNotification,
            object: nil,
            queue: .main
        ) { [weak self] notification in
            let app = notification.userInfo?[NSWorkspace.applicationUserInfoKey] as? NSRunningApplication
            let pid = app?.processIdentifier
            MainActor.assumeIsolated { self?.appDidActivate(pid: pid) }
        }
    }

    func stop() {
        pendingCheck?.cancel()
        pendingCheck = nil
        if let observer { NSWorkspace.shared.notificationCenter.removeObserver(observer) }
        observer = nil
    }

    private func appDidActivate(pid: pid_t?) {
        pendingCheck?.cancel()
        guard let pid, pid != ProcessInfo.processInfo.processIdentifier else { return }
        pendingCheck = Task { [weak self] in
            try? await Task.sleep(for: Self.overlayAppearanceDelay)
            guard let self, !Task.isCancelled, !NSApp.isActive else { return }
            if !Self.showsOverlay(pid: pid) {
                self.onForeignActivation()
            }
        }
    }

    /// Window layers and bounds are readable without the screen recording permission.
    private static func showsOverlay(pid: pid_t) -> Bool {
        let options: CGWindowListOption = [.optionOnScreenOnly, .excludeDesktopElements]
        guard let windows = CGWindowListCopyWindowInfo(options, kCGNullWindowID) as? [[CFString: Any]] else {
            return false
        }
        return windows.contains { window in
            guard (window[kCGWindowOwnerPID] as? pid_t) == pid,
                  let layer = window[kCGWindowLayer] as? Int, layer > 0,
                  let bounds = (window[kCGWindowBounds] as? NSDictionary).flatMap(CGRect.init(dictionaryRepresentation:))
            else { return false }
            let isStatusItem = bounds.height <= menuBarStripHeight
            return !isStatusItem && (window[kCGWindowAlpha] as? Double ?? 1) > 0
        }
    }
}
