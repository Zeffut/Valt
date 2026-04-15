// Valt/UI/Views/SettingsView.swift
import SwiftUI
import ApplicationServices

struct SettingsView: View {
    @AppStorage("valt.maxItems") private var maxItems: Int = 500
    @AppStorage("valt.maxDays") private var maxDays: Int = 0
    @State private var accessibilityGranted: Bool = AXIsProcessTrusted()

    private let itemOptions = [50, 100, 200, 500, 1000, 2000]

    var body: some View {
        Form {
            Section("Raccourci") {
                LabeledContent("Ouvrir Valt", value: "⌘⇧V")
                    .foregroundStyle(.secondary)
            }

            Section("Accessibilité") {
                LabeledContent("Statut") {
                    if accessibilityGranted {
                        Label("Autorisé", systemImage: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        Label("Non autorisé", systemImage: "xmark.circle.fill")
                            .foregroundStyle(.red)
                    }
                }

                if !accessibilityGranted {
                    Button("Autoriser l'accès…") {
                        requestAndRefresh()
                    }
                } else {
                    Button("Rouvrir le panneau d'accessibilité") {
                        requestAndRefresh()
                    }
                    .foregroundStyle(.secondary)
                }

                Text("Requis pour intercepter ⌘⇧V. À réaccorder après chaque mise à jour.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Historique") {
                Picker("Nombre d'éléments", selection: $maxItems) {
                    ForEach(itemOptions, id: \.self) { n in
                        Text("\(n) éléments").tag(n)
                    }
                }

                Picker("Durée de conservation", selection: $maxDays) {
                    Text("Indéfinie").tag(0)
                    Text("7 jours").tag(7)
                    Text("14 jours").tag(14)
                    Text("30 jours").tag(30)
                    Text("90 jours").tag(90)
                    Text("1 an").tag(365)
                }
            }

            Section("À propos") {
                LabeledContent("Version", value: "0.1.0")
            }
        }
        .formStyle(.grouped)
        .frame(width: 420, height: 400)
        .navigationTitle("Préférences")
        .onReceive(
            NotificationCenter.default.publisher(for: NSApplication.didBecomeActiveNotification)
        ) { _ in
            // Rafraîchit le statut quand l'utilisateur revient des Préférences Système
            accessibilityGranted = AXIsProcessTrusted()
        }
    }

    private func requestAndRefresh() {
        // 1. Supprime l'ancienne entrée (ancien hash binaire) — sinon macOS garde l'entrée
        //    révoquée cochée et n'ajoute pas la nouvelle dans la liste.
        let reset = Process()
        reset.executableURL = URL(fileURLWithPath: "/usr/bin/tccutil")
        reset.arguments = ["reset", "Accessibility", "com.valt.app"]
        try? reset.run()
        reset.waitUntilExit()

        // 2. Déclenche le prompt : ouvre Préférences Système avec Valt dans la liste,
        //    l'utilisateur n'a plus qu'à cocher.
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let key = "AXTrustedCheckOptionPrompt" as CFString
            let options = [key: true] as CFDictionary
            _ = AXIsProcessTrustedWithOptions(options)
            accessibilityGranted = false // révoqué jusqu'à ce que l'user coche
        }
    }
}
