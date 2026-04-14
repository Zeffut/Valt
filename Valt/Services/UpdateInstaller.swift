// Valt/Services/UpdateInstaller.swift
import AppKit
import Foundation

@MainActor
final class UpdateInstaller {
    static let shared = UpdateInstaller()

    private var window: NSWindow?
    private var progressBar: NSProgressIndicator?
    private var statusLabel: NSTextField?

    private init() {}

    func install(from downloadURL: URL) {
        buildProgressWindow()
        Task {
            do {
                let dmg = try await download(from: downloadURL)
                try install(dmg: dmg)
                statusLabel?.stringValue = "Relancement…"
                try await Task.sleep(for: .milliseconds(800))
                relaunch()
            } catch {
                window?.close()
                window = nil
                showError(error.localizedDescription)
            }
        }
    }

    // MARK: - Téléchargement

    private func download(from url: URL) async throws -> URL {
        setStatus("Téléchargement…", indeterminate: true)

        // Streaming pour avoir la progression
        let (asyncBytes, response) = try await URLSession.shared.bytes(from: url)
        let total = response.expectedContentLength
        var received: Int64 = 0
        var data = Data(capacity: total > 0 ? Int(total) : 10_000_000)

        progressBar?.isIndeterminate = false
        progressBar?.minValue = 0
        progressBar?.maxValue = 1

        for try await byte in asyncBytes {
            data.append(byte)
            received += 1
            if received % 50_000 == 0 {
                let pct = total > 0 ? Double(received) / Double(total) : 0
                progressBar?.doubleValue = pct
                statusLabel?.stringValue = String(format: "Téléchargement… %.0f%%", pct * 100)
            }
        }

        let dest = FileManager.default.temporaryDirectory.appendingPathComponent("Valt-update.dmg")
        try? FileManager.default.removeItem(at: dest)
        try data.write(to: dest, options: .atomic)
        return dest
    }

    // MARK: - Installation

    private func install(dmg: URL) throws {
        setStatus("Montage du DMG…", indeterminate: true)

        let mount = FileManager.default.temporaryDirectory.appendingPathComponent("ValtUpdateMount")
        try? FileManager.default.removeItem(at: mount)

        try shell("/usr/bin/hdiutil", args: [
            "attach", dmg.path,
            "-mountpoint", mount.path,
            "-quiet", "-nobrowse", "-readonly"
        ])

        defer {
            try? shell("/usr/bin/hdiutil", args: ["detach", mount.path, "-quiet"])
            try? FileManager.default.removeItem(at: dmg)
        }

        // Trouver le .app dans le volume monté
        let appInDMG = mount.appendingPathComponent("Valt.app")
        guard FileManager.default.fileExists(atPath: appInDMG.path) else {
            throw UpdateError.appNotFoundInDMG
        }

        setStatus("Installation…", indeterminate: true)

        let appDest = URL(fileURLWithPath: "/Applications/Valt.app")
        try? FileManager.default.removeItem(at: appDest)
        try FileManager.default.copyItem(at: appInDMG, to: appDest)

        setStatus("Signature…", indeterminate: true)

        // Supprimer la quarantaine puis re-signer
        try shell("/usr/bin/xattr", args: ["-cr", appDest.path])
        try shell("/usr/bin/codesign", args: [
            "--force", "--deep", "--sign", "Valt Developer", appDest.path
        ])
    }

    // MARK: - Relance

    private func relaunch() {
        // Lance un script shell détaché qui attend la fermeture de l'app puis la relance
        let appPath = Bundle.main.bundlePath
        Process.launchedProcess(launchPath: "/bin/zsh", arguments: [
            "-c", "sleep 1.5 && open '\(appPath)'"
        ])
        NSApp.terminate(nil)
    }

    // MARK: - Shell

    @discardableResult
    private func shell(_ path: String, args: [String]) throws -> Int32 {
        let p = Process()
        p.executableURL = URL(fileURLWithPath: path)
        p.arguments = args
        p.standardOutput = FileHandle.nullDevice
        p.standardError = FileHandle.nullDevice
        try p.run()
        p.waitUntilExit()
        guard p.terminationStatus == 0 else {
            throw UpdateError.commandFailed("\(path) \(args.joined(separator: " "))")
        }
        return p.terminationStatus
    }

    // MARK: - UI

    private func buildProgressWindow() {
        let win = NSWindow(
            contentRect: NSRect(x: 0, y: 0, width: 360, height: 100),
            styleMask: [.titled],
            backing: .buffered,
            defer: false
        )
        win.title = "Mise à jour de Valt"
        win.center()
        win.isReleasedWhenClosed = false

        let bar = NSProgressIndicator(frame: NSRect(x: 20, y: 50, width: 320, height: 20))
        bar.style = .bar
        bar.isIndeterminate = true
        bar.startAnimation(nil)
        win.contentView?.addSubview(bar)

        let label = NSTextField(frame: NSRect(x: 20, y: 20, width: 320, height: 20))
        label.isEditable = false
        label.isBordered = false
        label.backgroundColor = .clear
        label.stringValue = "Préparation…"
        label.font = .systemFont(ofSize: 12)
        label.textColor = .secondaryLabelColor
        win.contentView?.addSubview(label)

        self.progressBar = bar
        self.statusLabel = label
        self.window = win

        NSApp.activate(ignoringOtherApps: true)
        win.makeKeyAndOrderFront(nil)
    }

    private func setStatus(_ text: String, indeterminate: Bool) {
        statusLabel?.stringValue = text
        if indeterminate {
            progressBar?.isIndeterminate = true
            progressBar?.startAnimation(nil)
        }
    }

    private func showError(_ message: String) {
        let alert = NSAlert()
        alert.messageText = "Erreur de mise à jour"
        alert.informativeText = message
        alert.addButton(withTitle: "OK")
        alert.alertStyle = .critical
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}

// MARK: - Erreurs

enum UpdateError: LocalizedError {
    case appNotFoundInDMG
    case commandFailed(String)

    var errorDescription: String? {
        switch self {
        case .appNotFoundInDMG:    return "Valt.app introuvable dans le DMG."
        case .commandFailed(let c): return "Commande échouée : \(c)"
        }
    }
}
