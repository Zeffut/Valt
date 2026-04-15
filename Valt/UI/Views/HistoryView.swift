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
                    // .id force SwiftUI à recréer le ScrollView complet quand resetToken
                    // change → scroll offset revient à 0 naturellement → padding visible.
                    // C'est plus fiable que scrollTo() dont le comportement dépend du layout.
                    .id(selection.resetToken)
                    .onAppear { scrollProxy = proxy }
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
            if count > old {
                scrollProxy?.scrollTo(0, anchor: .center)
            }
        }
    }
}
