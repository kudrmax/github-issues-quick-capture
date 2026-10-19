import AppKit

protocol SystemActions {
    func copyToClipboard(_ text: String)
}

struct AppKitSystemActions: SystemActions {
    func copyToClipboard(_ text: String) {
        NSPasteboard.general.clearContents()
        NSPasteboard.general.setString(text, forType: .string)
    }
}
