import AppKit
import SwiftUI

/// The panel stays open until Esc, the hotkey or a created issue closes it.
/// While open the app is active, so clipboard managers and other tools that
/// return focus to the frontmost app paste into the panel.
@MainActor
final class PanelController {
    private static let cornerRadius: CGFloat = 14

    private let panel = FloatingPanel(contentSize: RootView.size)
    private let model: IssueBarViewModel
    private var keyMonitor: Any?

    init(model: IssueBarViewModel) {
        self.model = model
        panel.contentView = makeContentView()
        model.onDismiss = { [weak self] in self?.hide() }
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
        positionOnActiveScreen()
        installKeyMonitor()
        focus()
        panel.invalidateShadow()
    }

    func hide() {
        guard panel.isVisible else { return }
        removeKeyMonitor()
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
