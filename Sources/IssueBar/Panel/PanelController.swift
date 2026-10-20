import AppKit
import SwiftUI

/// The panel closes on Esc, the hotkey, a created issue or, like Spotlight,
/// when another app takes focus. The draft survives closing.
/// While open the app is active, so clipboard managers and other tools that
/// return focus to the frontmost app paste into the panel.
@MainActor
final class PanelController {
    private static let cornerRadius: CGFloat = 14

    private let panel = FloatingPanel(contentSize: IssueBarViewModel.compactPanelSize)
    private let model: IssueBarViewModel
    private var keyMonitor: Any?
    private lazy var activationWatcher = ForeignActivationWatcher { [weak self] in self?.hide() }

    init(model: IssueBarViewModel) {
        self.model = model
        panel.contentView = makeContentView()
        model.onDismiss = { [weak self] in self?.hide() }
        model.onPanelSizeChange = { [weak self] size in self?.resize(to: size, animated: true) }
    }

    func toggle() {
        if !panel.isVisible {
            show()
        } else if panel.isKeyWindow && NSApp.isActive {
            hide()
        } else {
            focus()
        }
    }

    func show() {
        model.panelWillOpen()
        resize(to: model.panelSize, animated: false)
        positionOnActiveScreen()
        installKeyMonitor()
        activationWatcher.start()
        focus()
        panel.invalidateShadow()
    }

    func hide() {
        guard panel.isVisible else { return }
        removeKeyMonitor()
        activationWatcher.stop()
        panel.orderOut(nil)
        if NSApp.isActive {
            NSApp.hide(nil)
        }
    }

    /// `hide()` leaves the app hidden, and activating a hidden app is refused
    /// until it is unhidden.
    private func focus() {
        if NSApp.isHidden {
            NSApp.unhideWithoutActivation()
        }
        NSApp.activate()
        panel.makeKeyAndOrderFront(nil)
        model.panelDidOpen()
    }

    private func makeContentView() -> NSView {
        let background = NSVisualEffectView()
        background.material = .popover
        background.blendingMode = .behindWindow
        background.state = .active
        background.maskImage = Self.roundedMask(radius: Self.cornerRadius)

        let host = NSHostingView(rootView: RootView(model: model, cornerRadius: Self.cornerRadius))
        host.sizingOptions = []
        host.translatesAutoresizingMaskIntoConstraints = false
        background.addSubview(host)
        NSLayoutConstraint.activate([
            host.leadingAnchor.constraint(equalTo: background.leadingAnchor),
            host.trailingAnchor.constraint(equalTo: background.trailingAnchor),
            host.topAnchor.constraint(equalTo: background.topAnchor),
            host.bottomAnchor.constraint(equalTo: background.bottomAnchor),
        ])
        return background
    }

    /// A layer corner radius doesn't clip the behind-window blur, a mask image does.
    private static func roundedMask(radius: CGFloat) -> NSImage {
        let edge = radius * 2 + 1
        let image = NSImage(size: NSSize(width: edge, height: edge), flipped: false) { rect in
            NSColor.black.setFill()
            NSBezierPath(roundedRect: rect, xRadius: radius, yRadius: radius).fill()
            return true
        }
        image.capInsets = NSEdgeInsets(top: radius, left: radius, bottom: radius, right: radius)
        image.resizingMode = .stretch
        return image
    }

    /// Grows and shrinks around the top edge, so the search field stays put.
    private func resize(to size: NSSize, animated: Bool) {
        let current = panel.frame
        guard current.size != size else { return }
        var frame = NSRect(x: current.midX - size.width / 2, y: current.maxY - size.height, width: size.width, height: size.height)
        if let visible = (panel.screen ?? NSScreen.main)?.visibleFrame {
            frame.origin.x = min(max(frame.minX, visible.minX), visible.maxX - frame.width)
            frame.origin.y = max(frame.minY, visible.minY)
        }
        panel.setFrame(frame, display: true, animate: animated && panel.isVisible)
        panel.invalidateShadow()
    }

    private func positionOnActiveScreen() {
        let mouse = NSEvent.mouseLocation
        let screen = NSScreen.screens.first { NSMouseInRect(mouse, $0.frame, false) } ?? NSScreen.main
        guard let frame = screen?.visibleFrame else { return }
        let size = panel.frame.size
        panel.setFrameOrigin(NSPoint(
            x: frame.midX - size.width / 2,
            y: frame.maxY - frame.height * 0.2 - size.height
        ))
    }

    private func installKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let command = KeyCommand(event: event) else { return event }
            if command == .quit {
                MainActor.assumeIsolated { NSApp.terminate(nil) }
                return nil
            }
            let windowNumber = event.windowNumber
            let isHandled = MainActor.assumeIsolated {
                guard let self, windowNumber == self.panel.windowNumber else { return false }
                return self.model.handle(command)
            }
            return isHandled ? nil : event
        }
    }

    private func removeKeyMonitor() {
        if let keyMonitor { NSEvent.removeMonitor(keyMonitor) }
        keyMonitor = nil
    }
}
