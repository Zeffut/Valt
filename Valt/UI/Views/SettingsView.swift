// Valt/UI/Views/SettingsView.swift
import SwiftUI

struct SettingsView: View {
    var body: some View {
        Form {
            Section("Raccourci") {
                LabeledContent("Ouvrir Valt", value: "⌘⇧V")
                    .foregroundStyle(.secondary)
            }

            Section("Historique") {
                LabeledContent("Limite", value: "500 éléments")
                    .foregroundStyle(.secondary)
            }

            Section("À propos") {
                LabeledContent("Version", value: "0.1.0")
            }
        }
        .formStyle(.grouped)
        .frame(width: 380, height: 240)
        .navigationTitle("Préférences")
    }
}
