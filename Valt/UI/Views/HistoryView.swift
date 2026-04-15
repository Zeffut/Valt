// Valt/UI/Views/HistoryView.swift
import SwiftUI

struct HistoryView: View {
    let items: [ClipItem]
    @ObservedObject var selection: SelectionModel
    let onPaste: (ClipItem) -> Void
    let onCopy: (ClipItem) -> Void
    let onPin: ((ClipItem) -> Void)?
    let onUnpin: ((ClipItem) -> Void)?

    // nil = pas de cible → ScrollView reste à son offset naturel (0 + contentMargins).
    // Quand HistoryView est recréée via .id(resetToken) dans ShelfView, ce @State repart
    // à nil → offset 0 garanti sans aucun appel à scrollTo().
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
                .scrollPosition(id: $scrolledID, anchor: .center)
                .onChange(of: selection.selectedIndex) { _, newIndex in
                    withAnimation(.easeInOut(duration: 0.15)) {
                        scrolledID = newIndex
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
