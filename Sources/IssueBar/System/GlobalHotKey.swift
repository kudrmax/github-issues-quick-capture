import AppKit
import Carbon.HIToolbox

/// System-wide shortcut via Carbon hot keys: works with any keyboard layout
/// and needs no Accessibility permission.
@MainActor
final class GlobalHotKey {
    struct Shortcut {
        let keyCode: UInt32
        let carbonModifiers: UInt32
        let displayString: String
        let menuKeyEquivalent: String
        let menuModifiers: NSEvent.ModifierFlags

        static let controlOptionI = Shortcut(
            keyCode: UInt32(kVK_ANSI_I),
            carbonModifiers: UInt32(controlKey | optionKey),
            displayString: "⌃⌥I",
            menuKeyEquivalent: "i",
            menuModifiers: [.control, .option]
        )
    }

    private static let signature: OSType = 0x4953_4252
    private static var actions: [UInt32: () -> Void] = [:]
    private static var nextID: UInt32 = 1
    private static var eventHandler: EventHandlerRef?

    private var hotKeyRef: EventHotKeyRef?

    init?(shortcut: Shortcut, action: @escaping () -> Void) {
        Self.installEventHandlerIfNeeded()
        let id = Self.nextID
        Self.nextID += 1

        let status = RegisterEventHotKey(
            shortcut.keyCode,
            shortcut.carbonModifiers,
            EventHotKeyID(signature: Self.signature, id: id),
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
        guard status == noErr else { return nil }
        Self.actions[id] = action
    }

    private static func installEventHandlerIfNeeded() {
        guard eventHandler == nil else { return }
        var eventType = EventTypeSpec(eventClass: OSType(kEventClassKeyboard), eventKind: UInt32(kEventHotKeyPressed))
        InstallEventHandler(GetApplicationEventTarget(), { _, event, _ in
            var hotKeyID = EventHotKeyID()
            GetEventParameter(
                event,
                EventParamName(kEventParamDirectObject),
                EventParamType(typeEventHotKeyID),
                nil,
                MemoryLayout<EventHotKeyID>.size,
                nil,
                &hotKeyID
            )
            let id = hotKeyID.id
            MainActor.assumeIsolated { GlobalHotKey.actions[id]?() }
            return noErr
        }, 1, &eventType, nil, &eventHandler)
    }
}
