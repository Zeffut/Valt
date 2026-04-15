// Valt/Services/HotkeyManager.swift
import AppKit
import Carbon

// C-compatible handler pour les Carbon hotkeys
private func carbonHotkeyHandler(
    _ nextHandler: EventHandlerCallRef?,
    _ event: EventRef?,
    _ userData: UnsafeMutableRawPointer?
) -> OSStatus {
    guard let userData else { return OSStatus(eventNotHandledErr) }
    let manager = Unmanaged<HotkeyManager>.fromOpaque(userData).takeUnretainedValue()
    DispatchQueue.main.async { manager.onToggle?() }
    return noErr
}

@MainActor
final class HotkeyManager {
    var onToggle: (() -> Void)?

    private var hotKeyRef: EventHotKeyRef?
    private var eventHandlerRef: EventHandlerRef?

    func start() {
        // ⌘⇧V — keyCode 9 = 'v', modifiers = cmd + shift
        let hotKeyID = EventHotKeyID(signature: OSType(0x56616C74), id: 1) // 'Valt'
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        var eventType = EventTypeSpec(
            eventClass: OSType(kEventClassKeyboard),
            eventKind: UInt32(kEventHotKeyPressed)
        )

        InstallEventHandler(
            GetApplicationEventTarget(),
            carbonHotkeyHandler,
            1,
            &eventType,
            selfPtr,
            &eventHandlerRef
        )

        RegisterEventHotKey(
            9,                             // keyCode 'v'
            UInt32(cmdKey | shiftKey),     // ⌘⇧
            hotKeyID,
            GetApplicationEventTarget(),
            0,
            &hotKeyRef
        )
    }

    func stop() {
        if let ref = hotKeyRef {
            UnregisterEventHotKey(ref)
            hotKeyRef = nil
        }
        if let handler = eventHandlerRef {
            RemoveEventHandler(handler)
            eventHandlerRef = nil
        }
    }
}
