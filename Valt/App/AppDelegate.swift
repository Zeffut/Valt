// Valt/App/AppDelegate.swift
@preconcurrency import AppKit

@MainActor
final class AppDelegate: NSObject, NSApplicationDelegate {
    private var statusItem: NSStatusItem!
    private let persistence = PersistenceController.shared
    private let monitor: ClipboardMonitor
    private let hotkeyManager = HotkeyManager()
    private var panelController: PanelController!

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
        requestAccessibility()
    }

    func applicationWillTerminate(_ notification: Notification) {
        monitor.stop()
        hotkeyManager.stop()
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

    @objc private func openSettings() {
        NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
    }

    @objc private func quit() { NSApp.terminate(nil) }

    private func requestAccessibility() {
        let options = [kAXTrustedCheckOptionPrompt.takeRetainedValue() as String: true] as CFDictionary
        _ = AXIsProcessTrustedWithOptions(options)
    }
}
