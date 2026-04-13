// Valt/Services/PasteboardService.swift
import AppKit

@MainActor
final class PasteboardService {
    static let shared = PasteboardService()
    private var previousApp: NSRunningApplication?

    private init() {}

    /// À appeler juste avant d'afficher le panneau
    func recordActiveApp() {
        previousApp = NSWorkspace.shared.frontmostApplication
    }

    func paste(_ item: ClipItem) {
        writeToClipboard(item)
        previousApp?.activate(options: [])
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.08) { [weak self] in
            self?.simulateCmdV()
        }
    }

    /// Copie dans le presse-papier sans coller (double-clic)
    func copy(_ item: ClipItem) {
        writeToClipboard(item)
    }

    private func writeToClipboard(_ item: ClipItem) {
        let pb = NSPasteboard.general
        pb.clearContents()
        switch item.type {
        case "text", "url":
            if let text = item.plainText { pb.setString(text, forType: .string) }
        case "image":
            if let image = NSImage(data: item.content) { pb.writeObjects([image]) }
        default:
            if let text = item.plainText { pb.setString(text, forType: .string) }
        }
    }

    private func simulateCmdV() {
        let src = CGEventSource(stateID: .hidSystemState)
        let down = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: true)
        down?.flags = .maskCommand
        down?.post(tap: .cghidEventTap)
        let up = CGEvent(keyboardEventSource: src, virtualKey: 0x09, keyDown: false)
        up?.flags = .maskCommand
        up?.post(tap: .cghidEventTap)
    }
}
