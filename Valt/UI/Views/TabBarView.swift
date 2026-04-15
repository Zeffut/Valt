// Valt/UI/Views/TabBarView.swift
import SwiftUI

struct TabBarView: View {
    @Binding var activeTab: ActiveTab

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Pinboard.position, ascending: true)],
        animation: .default
    )
    private var pinboards: FetchedResults<Pinboard>

    @Environment(\.managedObjectContext) private var context

    @State private var isCreating = false
    @State private var newName = ""
    @FocusState private var fieldFocused: Bool

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 2) {
                // Onglet Historique
                tabButton(title: "Historique", isSelected: activeTab == .history) {
                    activeTab = .history
                }

                // Onglets pinboards
                ForEach(pinboards) { pinboard in
                    tabButton(
                        title: pinboard.name,
                        isSelected: activeTab == .pinboard(pinboard)
                    ) {
                        activeTab = .pinboard(pinboard)
                    }
                    .contextMenu {
                        Button("Supprimer ce pinboard", role: .destructive) {
                            deletePinboard(pinboard)
                        }
                    }
                }

                // Champ de création inline
                if isCreating {
                    TextField("Nom…", text: $newName)
                        .textFieldStyle(.plain)
                        .font(.system(size: 12, weight: .medium))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 5)
                        .background(Color.accentColor.opacity(0.15))
                        .clipShape(Capsule())
                        .frame(width: 120)
                        .focused($fieldFocused)
                        .onSubmit { confirmCreation() }
                        .onKeyPress(.escape) { cancelCreation(); return .handled }
                        .onChange(of: fieldFocused) { _, focused in
                            if !focused { cancelCreation() }
                        }
                }

                // Bouton +
                Button {
                    isCreating = true
                    newName = ""
                    DispatchQueue.main.async { fieldFocused = true }
                } label: {
                    Image(systemName: "plus")
                        .font(.system(size: 11, weight: .medium))
                        .frame(width: 24, height: 24)
                        .background(Color.white.opacity(0.08))
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 6)
        }
        .focusEffectDisabled()
    }

    private func tabButton(title: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Text(title)
                .font(.system(size: 12, weight: isSelected ? .semibold : .regular))
                .padding(.horizontal, 12)
                .padding(.vertical, 5)
                .background(isSelected ? Color.accentColor.opacity(0.2) : Color.clear)
                .foregroundStyle(isSelected ? Color.accentColor : Color.secondary)
                .clipShape(Capsule())
        }
        .buttonStyle(.plain)
    }

    private func confirmCreation() {
        let name = newName.trimmingCharacters(in: .whitespaces)
        guard !name.isEmpty else { cancelCreation(); return }
        let pb = Pinboard.create(name: name, in: context)
        do { try context.save() } catch { print("[Valt] CoreData save failed: \(error)") }
        activeTab = .pinboard(pb)
        isCreating = false
    }

    private func cancelCreation() {
        isCreating = false
        newName = ""
    }

    private func deletePinboard(_ pinboard: Pinboard) {
        if activeTab == .pinboard(pinboard) {
            activeTab = .history
        }
        context.delete(pinboard)
        do { try context.save() } catch { print("[Valt] CoreData save failed: \(error)") }
    }
}
