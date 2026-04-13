// Valt/UI/Panel/PanelController.swift
import AppKit
import SwiftUI

@MainActor
final class PanelController {
    private var panel: PastePanel?
    private let persistence: PersistenceController
    private let pasteService: PasteboardService

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
        panel?.orderFrontRegardless()
        panel?.makeKey()
    }

    func hide() {
        panel?.orderOut(nil)
    }

    private func buildPanel() {
        let p = PastePanel()

        // Placeholder — sera remplacé par ShelfView dans Task 11
        let placeholder = Text("Valt — en construction")
            .font(.largeTitle)
            .foregroundStyle(.white)
            .frame(maxWidth: .infinity, maxHeight: .infinity)

        let host = NSHostingView(rootView: placeholder)
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
