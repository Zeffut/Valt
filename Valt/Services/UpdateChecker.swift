// Valt/Services/UpdateChecker.swift
import AppKit
import Foundation

@MainActor
final class UpdateChecker {
    static let shared = UpdateChecker()

    private static let apiURL = URL(string: "https://api.github.com/repos/Zeffut/Valt/releases/latest")!
    private static let checkIntervalSeconds: TimeInterval = 24 * 3600  // 1 fois par jour max
    private static let lastCheckKey = "valt.updateLastCheck"

    private init() {}

    /// Vérifie silencieusement au lancement (respecte l'intervalle quotidien).
    func checkOnLaunch() {
        let last = UserDefaults.standard.double(forKey: Self.lastCheckKey)
        let elapsed = Date().timeIntervalSince1970 - last
        guard elapsed > Self.checkIntervalSeconds else { return }
        Task { await check(silent: true) }
    }

    /// Vérification manuelle (depuis le menu ou les préférences).
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

    // MARK: - Comparaison de versions (SemVer)

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
        alert.messageText = "Mise à jour disponible"
        alert.informativeText = "Valt \(version) est disponible (version actuelle : \(current))."
        alert.addButton(withTitle: "Télécharger")
        alert.addButton(withTitle: "Plus tard")
        alert.alertStyle = .informational

        NSApp.activate(ignoringOtherApps: true)
        if alert.runModal() == .alertFirstButtonReturn {
            if let url = URL(string: release.htmlURL) {
                NSWorkspace.shared.open(url)
            }
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

// MARK: - Modèle GitHub API

private struct GitHubRelease: Decodable {
    let tagName: String
    let htmlURL: String

    enum CodingKeys: String, CodingKey {
        case tagName = "tag_name"
        case htmlURL = "html_url"
    }
}
