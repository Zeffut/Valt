// Valt/Services/HotkeyManager.swift
import AppKit
import CoreGraphics

// C-compatible callback — free function pour pouvoir être passée comme pointeur C
private func eventTapCallback(
    proxy: CGEventTapProxy,
    type: CGEventType,
    event: CGEvent,
    refcon: UnsafeMutableRawPointer?
) -> Unmanaged<CGEvent>? {
    guard type == .keyDown, let refcon else {
        return Unmanaged.passUnretained(event)
    }

    let keyCode = event.getIntegerValueField(.keyboardEventKeycode)
    let flags = event.flags

    // ⌘⇧V : keyCode 9, command + shift
    guard keyCode == 9,
          flags.contains(.maskCommand),
          flags.contains(.maskShift) else {
        return Unmanaged.passUnretained(event)
    }

    let manager = Unmanaged<HotkeyManager>.fromOpaque(refcon).takeUnretainedValue()
    DispatchQueue.main.async { manager.onToggle?() }

    return nil // Consomme l'event — ne le transmet pas à l'app active
}

@MainActor
final class HotkeyManager {
    var onToggle: (() -> Void)?

    private var eventTap: CFMachPort?
    private var runLoopSource: CFRunLoopSource?

    func start() {
        let mask = CGEventMask(1 << CGEventType.keyDown.rawValue)
        let selfPtr = Unmanaged.passUnretained(self).toOpaque()

        guard let tap = CGEvent.tapCreate(
            tap: .cgSessionEventTap,
            place: .headInsertEventTap,
            options: .defaultTap,
            eventsOfInterest: mask,
            callback: eventTapCallback,
            userInfo: selfPtr
        ) else {
            print("HotkeyManager: CGEventTap failed — vérifier la permission d'accessibilité")
            return
        }

        let source = CFMachPortCreateRunLoopSource(kCFAllocatorDefault, tap, 0)
        CFRunLoopAddSource(CFRunLoopGetMain(), source, .commonModes)
        CGEvent.tapEnable(tap: tap, enable: true)

        eventTap = tap
        runLoopSource = source
    }

    func stop() {
        if let tap = eventTap {
            CGEvent.tapEnable(tap: tap, enable: false)
        }
        if let source = runLoopSource {
            CFRunLoopRemoveSource(CFRunLoopGetMain(), source, .commonModes)
        }
        eventTap = nil
        runLoopSource = nil
    }
}
