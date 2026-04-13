// Valt/Services/HotkeyManager.swift
import AppKit

/// Détecte ⌘⇧V globalement via NSEvent monitors.
/// Nécessite la permission d'accessibilité (demandée depuis AppDelegate).
@MainActor
final class HotkeyManager {
    var onToggle: (() -> Void)?

    private var globalMonitor: Any?
    private var localMonitor: Any?

    func start() {
        globalMonitor = NSEvent.addGlobalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handle(event)
        }
        localMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            self?.handle(event)
            return event
        }
    }

    func stop() {
        [globalMonitor, localMonitor].compactMap { $0 }.forEach(NSEvent.removeMonitor)
        globalMonitor = nil
        localMonitor = nil
    }

    private func handle(_ event: NSEvent) {
        guard event.keyCode == 9,                          // V key
              event.modifierFlags.contains(.command),
              event.modifierFlags.contains(.shift) else { return }
        Task { @MainActor [weak self] in self?.onToggle?() }
    }
}
