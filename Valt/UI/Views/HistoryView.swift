// Valt/UI/Views/HistoryView.swift
import SwiftUI

struct HistoryView: View {
    let items: [ClipItem]
    @ObservedObject var selection: SelectionModel
    let onPaste: (ClipItem) -> Void
    let onCopy: (ClipItem) -> Void
    let onTogglePin: ((ClipItem) -> Void)?

    @State private var scrolledID: Int? = nil

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if items.isEmpty {
                ContentUnavailableView(
                    "Aucun élément",
                    systemImage: "doc.on.clipboard",
                    description: Text("Copiez quelque chose pour commencer")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 12) {
                        ForEach(Array(items.enumerated()), id: \.element.objectID) { index, item in
                            if !item.isDeleted {
                                ClipCellView(
                                    item: item,
                                    isSelected: selection.selectedIndex == index,
                                    onPaste: { onPaste(item) },
                                    onCopy: { onCopy(item) },
                                    onTogglePin: onTogglePin.map { toggle in { toggle(item) } }
                                )
                                .id(index)
                            }
                        }
                    }
                    .padding(.vertical, 12)
                }
                .contentMargins(.horizontal, 16, for: .scrollContent)
                .scrollPosition(id: $scrolledID, anchor: .center)
                .onChange(of: selection.selectedIndex) { _, newIndex in
                    if newIndex == 0 {
                        scrolledID = nil
                    } else {
                        withAnimation(.easeInOut(duration: 0.15)) {
                            scrolledID = newIndex
                        }
                    }
                }
            }
        }
        .onAppear {
            selection.count = items.count
        }
        .onChange(of: items.count) { _, count in
            selection.count = count
            // Clamp l'index après suppression pour éviter un accès hors-bornes
            if selection.selectedIndex >= count {
                selection.selectedIndex = max(0, count - 1)
            }
        }
    }
}
