// Valt/UI/Views/SettingsView.swift
import SwiftUI

struct SettingsView: View {
    @AppStorage("valt.maxItems") private var maxItems: Int = 500
    @AppStorage("valt.maxDays") private var maxDays: Int = 0

    private let itemOptions = [50, 100, 200, 500, 1000, 2000]
    private let dayOptions  = [0, 7, 14, 30, 90, 365]

    var body: some View {
        Form {
            Section("Raccourci") {
                LabeledContent("Ouvrir Valt", value: "⌘⇧V")
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
        .frame(width: 380, height: 280)
        .navigationTitle("Préférences")
    }
}
