// Valt/UI/Views/HistoryView.swift
import SwiftUI

struct HistoryView: View {
    let items: [ClipItem]
    @ObservedObject var selection: SelectionModel
    let onPaste: (ClipItem) -> Void
    let onCopy: (ClipItem) -> Void
    let onPin: ((ClipItem) -> Void)?
    let onUnpin: ((ClipItem) -> Void)?

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
                // .id(resetToken) sur le ScrollViewReader entier : quand le token change
                // (changement d'onglet, recherche), SwiftUI recrée tout le bloc desde zéro.
                // Le nouveau ScrollView démarre naturellement à offset 0 et contentMargins
                // garantit que le padding 16px est visible dès le premier rendu.
                ScrollViewReader { proxy in
                    ScrollView(.horizontal, showsIndicators: false) {
                        LazyHStack(spacing: 12) {
                            ForEach(Array(items.enumerated()), id: \.offset) { index, item in
                                ClipCellView(
                                    item: item,
                                    isSelected: selection.selectedIndex == index,
                                    onPaste: { onPaste(item) },
                                    onCopy: { onCopy(item) },
                                    onPin: onPin.map { pin in { pin(item) } },
                                    onUnpin: onUnpin.map { unpin in { unpin(item) } }
                                )
                                .id(index)
                            }
                        }
                        .padding(.vertical, 12)
                    }
                    .contentMargins(.horizontal, 16, for: .scrollContent)
                    .onChange(of: selection.selectedIndex) { _, newIndex in
                        withAnimation(.easeInOut(duration: 0.15)) {
                            proxy.scrollTo(newIndex, anchor: .center)
                        }
                    }
                }
            }
        }
        .onAppear {
            selection.count = items.count
        }
        .onChange(of: items.count) { old, count in
            selection.count = count
        }
    }
}
