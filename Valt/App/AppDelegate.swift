// Valt/App/AppDelegate.swift
@preconcurrency import AppKit
import SwiftUI

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let persistence = PersistenceController.shared
    private let monitor: ClipboardMonitor
    private let hotkeyManager = HotkeyManager()
    private var panelController: PanelController!
    private var settingsWindow: NSWindow?

    override init() {
        monitor = ClipboardMonitor(persistence: PersistenceController.shared)
        super.init()
    }

    func applicationDidFinishLaunching(_ notification: Notification) {
        NSApp.setActivationPolicy(.accessory)

        panelController = PanelController(
            persistence: persistence,
            pasteService: PasteboardService.shared,
            monitor: monitor
        )

        hotkeyManager.onToggle = { [weak self] in
            self?.panelController.toggle()
        }

        hotkeyManager.start()
        monitor.start()
        buildStatusBar()
        // Vérification silencieuse au lancement (max 1 fois/jour)
        UpdateChecker.shared.checkOnLaunch()
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
        hotkeyManager.stop()
    }

    // Double-clic sur l'icône app (Finder/Dock) → ouvre le panneau au lieu de relancer
    func applicationShouldHandleReopen(_ sender: NSApplication, hasVisibleWindows: Bool) -> Bool {
        panelController.show()
        return false
    }

    private func buildStatusBar() {
        statusItem = NSStatusBar.system.statusItem(withLength: NSStatusItem.squareLength)
        statusItem.button?.image = NSImage(
            systemSymbolName: "doc.on.clipboard",
            accessibilityDescription: "Valt"
        )

        let menu = NSMenu()
        let openItem = NSMenuItem(
            title: "Ouvrir Valt",
            action: #selector(openPanel),
            keyEquivalent: ""
        )
        openItem.target = self
        menu.addItem(openItem)
        menu.addItem(.separator())
        let settingsItem = NSMenuItem(
            title: "Préférences...",
            action: #selector(openSettings),
            keyEquivalent: ","
        )
        settingsItem.target = self
        menu.addItem(settingsItem)
        let updateItem = NSMenuItem(
            title: "Vérifier les mises à jour...",
            action: #selector(checkForUpdates),
            keyEquivalent: ""
        )
        updateItem.target = self
        menu.addItem(updateItem)
        menu.addItem(.separator())
        let quitItem = NSMenuItem(
            title: "Quitter Valt",
            action: #selector(quit),
            keyEquivalent: "q"
        )
        quitItem.target = self
        menu.addItem(quitItem)

        statusItem.menu = menu
    }

    @objc private func openPanel() { panelController.show() }

    @objc func openSettings() {
        if settingsWindow == nil {
            let win = NSWindow(
                contentRect: NSRect(x: 0, y: 0, width: 380, height: 280),
                styleMask: [.titled, .closable, .miniaturizable],
                backing: .buffered,
                defer: false
            )
            win.title = "Préférences Valt"
            win.center()
            win.isReleasedWhenClosed = false
            win.contentView = NSHostingView(rootView: SettingsView())
            settingsWindow = win
        }
        NSApp.activate(ignoringOtherApps: true)
        settingsWindow?.makeKeyAndOrderFront(nil)
    }

    @objc private func checkForUpdates() { UpdateChecker.shared.checkNow() }

    @objc private func quit() { NSApp.terminate(nil) }

}
