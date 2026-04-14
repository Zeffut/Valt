// Valt/Services/UpdateChecker.swift
import AppKit
import Foundation

@MainActor
final class UpdateChecker {
    static let shared = UpdateChecker()

    private static let apiURL = URL(string: "https://api.github.com/repos/Zeffut/Valt/releases/latest")!
    private static let checkIntervalSeconds: TimeInterval = 24 * 3600
    private static let lastCheckKey = "valt.updateLastCheck"

    private init() {}

    func checkOnLaunch() {
        let last = UserDefaults.standard.double(forKey: Self.lastCheckKey)
        let elapsed = Date().timeIntervalSince1970 - last
        guard elapsed > Self.checkIntervalSeconds else { return }
        Task { await check(silent: true) }
    }

    func checkNow() {
        Task { await check(silent: false) }
    }

    // MARK: - Core

    private func check(silent: Bool) async {
        var request = URLRequest(url: Self.apiURL)
        request.setValue("application/vnd.github+json", forHTTPHeaderField: "Accept")
        request.timeoutInterval = 10

        guard let (data, _) = try? await URLSession.shared.data(for: request),
              let release = try? JSONDecoder().decode(GitHubRelease.self, from: data)
        else {
            if !silent { showError() }
            return
        }

        UserDefaults.standard.set(Date().timeIntervalSince1970, forKey: Self.lastCheckKey)

        let remoteVersion = release.tagName.trimmingCharacters(in: CharacterSet(charactersIn: "v"))
        let currentVersion = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? "0.0.0"

        if isNewer(remoteVersion, than: currentVersion) {
            showUpdateAlert(version: remoteVersion, release: release)
        } else if !silent {
            showUpToDateAlert(version: currentVersion)
        }
    }

    // MARK: - Comparaison SemVer

    private func isNewer(_ remote: String, than current: String) -> Bool {
        let r = remote.split(separator: ".").compactMap { Int($0) }
        let c = current.split(separator: ".").compactMap { Int($0) }
        for i in 0..<max(r.count, c.count) {
            let rv = i < r.count ? r[i] : 0
            let cv = i < c.count ? c[i] : 0
            if rv != cv { return rv > cv }
        }
        return false
    }

    // MARK: - UI

    private func showUpdateAlert(version: String, release: GitHubRelease) {
        let current = Bundle.main.infoDictionary?["CFBundleShortVersionString"] as? String ?? ""
        let alert = NSAlert()
        alert.messageText = "Mise à jour disponible — Valt \(version)"
        alert.informativeText = "Version actuelle : \(current)\n\nValt va télécharger et installer la mise à jour automatiquement, puis se relancer."
        alert.addButton(withTitle: "Installer maintenant")
        alert.addButton(withTitle: "Plus tard")
        alert.alertStyle = .informational

        NSApp.activate(ignoringOtherApps: true)
        guard alert.runModal() == .alertFirstButtonReturn else { return }

        // Chercher l'asset .dmg dans la release
        if let asset = release.assets.first(where: { $0.name.hasSuffix(".dmg") }),
           let downloadURL = URL(string: asset.browserDownloadURL) {
            UpdateInstaller.shared.install(from: downloadURL)
        } else if let fallbackURL = URL(string: release.htmlURL) {
            // Pas de DMG dans les assets → ouvrir la page de release
            NSWorkspace.shared.open(fallbackURL)
        }
    }

    private func showUpToDateAlert(version: String) {
        let alert = NSAlert()
        alert.messageText = "Valt est à jour"
        alert.informativeText = "Vous utilisez la dernière version (\(version))."
        alert.addButton(withTitle: "OK")
        alert.alertStyle = .informational
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }

    private func showError() {
        let alert = NSAlert()
        alert.messageText = "Impossible de vérifier les mises à jour"
        alert.informativeText = "Vérifiez votre connexion et réessayez."
        alert.addButton(withTitle: "OK")
        alert.alertStyle = .warning
        NSApp.activate(ignoringOtherApps: true)
        alert.runModal()
    }
}

// MARK: - Modèles GitHub API

private struct GitHubRelease: Decodable {
    let tagName: String
    let htmlURL: String
    let assets: [Asset]

    struct Asset: Decodable {
        let name: String
        let browserDownloadURL: String

        enum CodingKeys: String, CodingKey {
            case name
            case browserDownloadURL = "browser_download_url"
        }
    }

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
        case assets
    }
}
