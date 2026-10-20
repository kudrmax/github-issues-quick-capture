import AppKit
import Carbon.HIToolbox

extension KeyCommand {
    private static let digitKeyCodes = [
        kVK_ANSI_1, kVK_ANSI_2, kVK_ANSI_3, kVK_ANSI_4, kVK_ANSI_5,
        kVK_ANSI_6, kVK_ANSI_7, kVK_ANSI_8, kVK_ANSI_9,
    ]

    /// Matches physical keys, so ⌘W / ⌘Q also work in the Russian layout.
    /// Shift+Return and Option+Return intentionally map to nothing,
    /// so the text editor inserts a line break.
    init?(event: NSEvent) {
        let modifiers = event.modifierFlags.intersection([.shift, .control, .option, .command])
        switch Int(event.keyCode) {
        case kVK_UpArrow where modifiers.isEmpty:
            self = .moveUp
        case kVK_DownArrow where modifiers.isEmpty:
            self = .moveDown
        case kVK_LeftArrow where modifiers.isEmpty:
            self = .moveLeft
        case kVK_RightArrow where modifiers.isEmpty:
            self = .moveRight
        case kVK_Return where modifiers.isEmpty, kVK_ANSI_KeypadEnter where modifiers.isEmpty:
            self = .submit
        case kVK_Return where modifiers == .command, kVK_ANSI_KeypadEnter where modifiers == .command:
            self = .commandSubmit
        case kVK_Escape:
            self = .back
        case kVK_Tab where modifiers.isEmpty || modifiers == .shift:
            self = .switchMode
        case kVK_ANSI_W where modifiers == .command:
            self = .close
        case kVK_ANSI_Q where modifiers == .command:
            self = .quit
        case let keyCode where modifiers == .command && Self.digitKeyCodes.contains(keyCode):
            self = .toggleLabel(Self.digitKeyCodes.firstIndex(of: keyCode)!)
        default:
            return nil
        }
    }
}

extension KeyCommand {
    /// ← and → switch screens only from the edge of the focused text,
    /// otherwise they move the caret as usual. Other commands always pass.
    @MainActor
    func reachesBeyondText(in textView: NSTextView?) -> Bool {
        guard self == .moveLeft || self == .moveRight, let textView else { return true }
        let selection = textView.selectedRange()
        guard selection.length == 0 else { return false }
        return self == .moveLeft ? selection.location == 0 : selection.location == textView.string.utf16.count
    }
}
