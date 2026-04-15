// Valt/UI/Views/HistoryView.swift
import SwiftUI

struct HistoryView: View {
    let items: [ClipItem]
    @ObservedObject var selection: SelectionModel
    let onPaste: (ClipItem) -> Void
    let onCopy: (ClipItem) -> Void
    let onPin: ((ClipItem) -> Void)?
    let onUnpin: ((ClipItem) -> Void)?

    @State private var scrollProxy: ScrollViewProxy? = nil

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
                            // Ancre de début : scrollTo("start") respecte le padding horizontal
                            Color.clear.frame(width: 0).id("start")
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
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .onAppear { scrollProxy = proxy }
                    .onChange(of: selection.selectedIndex) { _, newIndex in
                        withAnimation(.easeInOut(duration: 0.15)) {
                            proxy.scrollTo(newIndex, anchor: .center)
                        }
                    }
                    .onChange(of: selection.resetToken) { _, _ in
                        DispatchQueue.main.async {
                            proxy.scrollTo("start", anchor: .leading)
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
            // Nouvel item capturé → scroll automatique vers le plus récent
            if count > old {
                scrollProxy?.scrollTo("start", anchor: .leading)
            }
        }
    }
}
