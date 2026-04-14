// Valt/UI/Views/HistoryView.swift
import SwiftUI

struct HistoryView: View {
    let items: [ClipItem]
    let selection: SelectionModel
    let onPaste: (ClipItem) -> Void
    let onCopy: (ClipItem) -> Void

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
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 12) {
                            ForEach(Array(items.enumerated()), id: \.element.id) { index, item in
                                ClipCellView(
                                    item: item,
                                    isSelected: selection.selectedIndex == index,
                                    onPaste: { onPaste(item) },
                                    onCopy: { onCopy(item) }
                                )
                                .id(index)
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .onChange(of: selection.selectedIndex) { _, newIndex in
                        withAnimation(.easeInOut(duration: 0.15)) {
                            proxy.scrollTo(newIndex, anchor: .center)
                        }
                    }
                    // Réouverture du panneau → scroll immédiat vers l'item 0 (le plus récent)
                    .onChange(of: selection.resetToken) { _, _ in
                        proxy.scrollTo(0, anchor: .leading)
                    }
                }
            }
        }
        .onAppear {
            selection.count = items.count
        }
        .onChange(of: items.count) { _, count in
            selection.count = count
        }
    }
}
