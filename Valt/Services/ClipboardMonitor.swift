// Valt/Services/ClipboardMonitor.swift
import AppKit
import CoreData

@MainActor
final class ClipboardMonitor {
    private var timer: Timer?
    private var lastChangeCount: Int
    private let persistence: PersistenceController

    private var maxItems: Int { let v = UserDefaults.standard.integer(forKey: "valt.maxItems"); return v > 0 ? v : 500 }
    private var maxDays: Int  { UserDefaults.standard.integer(forKey: "valt.maxDays") }
    private var fastPolling = false

    init(persistence: PersistenceController = .shared) {
        self.persistence = persistence
        self.lastChangeCount = NSPasteboard.general.changeCount
    }

    func start() {
        scheduleTimer(interval: 2.0) // lent par défaut, s'accélère à l'ouverture du panneau
    }

    func stop() {
        timer?.invalidate()
        timer = nil
    }

    /// Appelé par PanelController : poll immédiat + 0.5s quand panneau visible, 2s sinon
    func setFastPolling(_ fast: Bool) {
        guard fast != fastPolling else { return }
        fastPolling = fast
        timer?.invalidate()
        if fast { poll() } // capture immédiate à l'ouverture
        scheduleTimer(interval: fast ? 0.5 : 2.0)
    }

    private func scheduleTimer(interval: TimeInterval) {
        timer = Timer.scheduledTimer(withTimeInterval: interval, repeats: true) { [weak self] _ in
            Task { @MainActor [weak self] in self?.poll() }
        }
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

        // Un seul save — purgeOldItems ne save plus lui-même
        ClipItem.purgeOldItems(keeping: maxItems, olderThan: maxDays, in: context)
        persistence.save()
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
