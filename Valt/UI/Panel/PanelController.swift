// Valt/UI/Panel/PanelController.swift
import AppKit
import SwiftUI

@MainActor
final class PanelController {
    private var panel: PastePanel?
    private let persistence: PersistenceController
    private let pasteService: PasteboardService
    private let monitor: ClipboardMonitor
    private let selection = SelectionModel()
    private var keyMonitor: Any?
    private var resignObserver: Any?

    init(persistence: PersistenceController, pasteService: PasteboardService, monitor: ClipboardMonitor) {
        self.persistence = persistence
        self.pasteService = pasteService
        self.monitor = monitor
    }

    func toggle() {
        if panel?.isVisible == true { hide() } else { show() }
    }

    func show() {
        pasteService.recordActiveApp()
        // Reconstruire à chaque ouverture pour garantir un rendu SwiftUI frais.
        // Le panel réutilisé peut afficher du contenu périmé si SwiftUI a raté
        // une mise à jour pendant que la fenêtre était cachée.
        tearDownPanel()
        buildPanel()
        NSApp.activate(ignoringOtherApps: true)
        panel?.orderFrontRegardless()
        panel?.makeKey()
        startKeyMonitor()
        monitor.setFastPolling(true)
        selection.reset()
    }

    func hide() {
        tearDownPanel()
        stopKeyMonitor()
        selection.reset()
        monitor.setFastPolling(false)
    }

    // MARK: - Nettoyage

    private func tearDownPanel() {
        if let obs = resignObserver {
            NotificationCenter.default.removeObserver(obs)
            resignObserver = nil
        }
        panel?.orderOut(nil)
        panel = nil
    }

    // MARK: - Keyboard navigation

    private func startKeyMonitor() {
        guard keyMonitor == nil else { return }
        // Moniteur LOCAL : reçoit les touches destinées à notre app (quand elle est active).
        // NSApp.activate() dans show() garantit que l'app est active avant l'enregistrement.
        // Retourne nil pour consommer la touche (empêche le scroll de la ScrollView).
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
        if let m = keyMonitor {
            NSEvent.removeMonitor(m)
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

        resignObserver = NotificationCenter.default.addObserver(
            forName: NSWindow.didResignKeyNotification,
            object: p,
            queue: .main
        ) { [weak self] _ in self?.hide() }

        panel = p
    }
}
