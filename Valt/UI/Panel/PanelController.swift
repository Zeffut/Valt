// Valt/UI/Panel/PanelController.swift
import AppKit
import SwiftUI

@MainActor
final class PanelController {
    private var panel: PastePanel?
    private let persistence: PersistenceController
    private let pasteService: PasteboardService
    private let selection = SelectionModel()
    private var keyMonitor: Any?

    init(persistence: PersistenceController, pasteService: PasteboardService) {
        self.persistence = persistence
        self.pasteService = pasteService
    }

    func toggle() {
        if panel?.isVisible == true { hide() } else { show() }
    }

    func show() {
        pasteService.recordActiveApp()
        if panel == nil { buildPanel() }
        selection.reset()
        panel?.orderFrontRegardless()
        panel?.makeKey()
        startKeyMonitor()
    }

    func hide() {
        panel?.orderOut(nil)
        stopKeyMonitor()
        selection.reset()
    }

    // MARK: - Keyboard navigation

    private func startKeyMonitor() {
        guard keyMonitor == nil else { return }
        keyMonitor = NSEvent.addLocalMonitorForEvents(matching: .keyDown) { [weak self] event in
            guard let self else { return event }
            switch event.keyCode {
            case 123: self.selection.moveLeft();    return nil  // ← flèche gauche
            case 124: self.selection.moveRight();   return nil  // → flèche droite
            case 36, 76: self.selection.triggerPaste(); return nil  // Return / numpad Enter
            default:  return event
            }
        }
    }

    private func stopKeyMonitor() {
        if let monitor = keyMonitor {
            NSEvent.removeMonitor(monitor)
            keyMonitor = nil
        }
    }

    // MARK: - Panel construction

    private func buildPanel() {
        let p = PastePanel()

        let root = ShelfView(
            persistence: persistence,
            selection: selection,
            onPaste: { [weak self] item in
                self?.hide()
                self?.pasteService.paste(item)
            },
            onCopy: { item in
                PasteboardService.shared.copy(item)
            },
            onDismiss: { [weak self] in
                self?.hide()
            }
        )
        .environment(\.managedObjectContext, persistence.context)

        let host = NSHostingView(rootView: root)
        host.frame = p.contentView!.bounds
        host.autoresizingMask = [.width, .height]
        p.contentView!.addSubview(host)

        NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: p,
            queue: .main
        ) { [weak self] _ in self?.hide() }

        panel = p
    }
}
