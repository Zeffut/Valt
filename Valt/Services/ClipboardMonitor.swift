// Valt/Services/ClipboardMonitor.swift
import AppKit
import CoreData

@MainActor
final class ClipboardMonitor {
    private var timer: Timer?
    private var lastChangeCount: Int
    private let maxItems = 500
    private let persistence: PersistenceController

    init(persistence: PersistenceController = .shared) {
        self.persistence = persistence
        self.lastChangeCount = NSPasteboard.general.changeCount
    }

    func start() {
        timer = Timer.scheduledTimer(withTimeInterval: 0.5, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.poll() }
        }
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    private func poll() {
        let current = NSPasteboard.general.changeCount
        guard current != lastChangeCount else { return }
        lastChangeCount = current
        capture()
    }

    private func capture() {
        let pasteboard = NSPasteboard.general
        let context = persistence.context

        if let string = pasteboard.string(forType: .string) {
            // Éviter les doublons consécutifs
            if let latest = ClipItem.fetchLatest(in: context),
               latest.type == clipType(for: string),
               latest.plainText == string { return }

            _ = ClipItem.create(
                content: Data(string.utf8),
                type: clipType(for: string),
                plainText: string,
                sourceApp: frontBundleID(),
                sourceAppName: frontAppName(),
                in: context
            )

        } else if let image = NSImage(pasteboard: pasteboard),
                  let tiff = image.tiffRepresentation {
            if let latest = ClipItem.fetchLatest(in: context),
               latest.type == "image",
               latest.content == tiff { return }

            _ = ClipItem.create(
                content: tiff,
                type: "image",
                plainText: nil,
                sourceApp: frontBundleID(),
                sourceAppName: frontAppName(),
                in: context
            )
        } else {
            return
        }

        persistence.save()
        ClipItem.purgeOldItems(keeping: maxItems, in: context)
    }

    private func clipType(for string: String) -> String {
        string.hasPrefix("http://") || string.hasPrefix("https://") ? "url" : "text"
    }

    private func frontBundleID() -> String? {
        NSWorkspace.shared.frontmostApplication?.bundleIdentifier
    }

    private func frontAppName() -> String? {
        NSWorkspace.shared.frontmostApplication?.localizedName
    }
}
