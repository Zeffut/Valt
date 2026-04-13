// Valt/UI/Views/HistoryView.swift
import SwiftUI

struct HistoryView: View {
    let items: [ClipItem]
    let onPaste: (ClipItem) -> Void
    let onCopy: (ClipItem) -> Void
    let onPin: ((ClipItem) -> Void)?

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text("Historique")
                .font(.system(size: 11, weight: .semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 16)
                .padding(.vertical, 6)

            if items.isEmpty {
                ContentUnavailableView(
                    "Aucun élément",
                    systemImage: "doc.on.clipboard",
                    description: Text("Copiez quelque chose pour commencer")
                )
                .frame(maxWidth: .infinity, maxHeight: .infinity)
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    LazyHStack(spacing: 10) {
                        ForEach(items, id: \.id) { item in
                            ClipCellView(
                                item: item,
                                onPaste: { onPaste(item) },
                                onCopy: { onCopy(item) },
                                onPin: onPin.map { action in { action(item) } }
                            )
                        }
                    }
                    .padding(.horizontal, 16)
                    .padding(.bottom, 12)
                }
            }
        }
    }
}
