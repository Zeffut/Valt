// Valt/App/ValtApp.swift
import SwiftUI

@main
struct ValtApp: App {
    @NSApplicationDelegateAdaptor(AppDelegate.self) private var delegate

    var body: some Scene {
        Settings {
            SettingsView()
        }
    }
}
