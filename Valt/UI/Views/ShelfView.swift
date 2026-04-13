// Valt/UI/Views/ShelfView.swift
import SwiftUI
import CoreData

struct ShelfView: View {
    let persistence: PersistenceController
    let onPaste: (ClipItem) -> Void
    let onCopy: (ClipItem) -> Void
    let onDismiss: () -> Void

    @State private var searchQuery = ""
    @State private var searchService: SearchService

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ClipItem.createdAt, ascending: false)],
        predicate: NSPredicate(format: "pinboard == nil"),
        animation: .default
    )
    private var historyItems: FetchedResults<ClipItem>

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \Pinboard.position, ascending: true)],
        animation: .default
    )
    private var pinboards: FetchedResults<Pinboard>

    init(
        persistence: PersistenceController,
        onPaste: @escaping (ClipItem) -> Void,
        onCopy: @escaping (ClipItem) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.persistence = persistence
        self.onPaste = onPaste
        self.onCopy = onCopy
        self.onDismiss = onDismiss
        _searchService = State(initialValue: SearchService(context: persistence.context))
    }

    private var displayedItems: [ClipItem] {
        searchQuery.isEmpty ? Array(historyItems) : searchService.results
    }

    var body: some View {
        VStack(spacing: 0) {
            // Barre du haut
            HStack(spacing: 12) {
                SearchBarView(query: $searchQuery)
                    .onChange(of: searchQuery) { _, new in
                        searchService.search(new)
                    }
                Spacer()
                Button {
                    NSApp.sendAction(Selector(("showSettingsWindow:")), to: nil, from: nil)
                } label: {
                    Image(systemName: "gear")
                        .font(.system(size: 15))
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
                .padding(.trailing, 16)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(.ultraThinMaterial)

            Divider()

            // Contenu 2 colonnes
            HStack(spacing: 0) {
                HistoryView(
                    items: displayedItems,
                    onPaste: onPaste,
                    onCopy: onCopy,
                    onPin: { item in pinItem(item) }
                )
                .frame(maxWidth: .infinity)

                Divider()

                PinboardView(
                    pinboards: Array(pinboards),
                    onPaste: onPaste,
                    onCopy: onCopy,
                    context: persistence.context
                )
                .frame(maxWidth: .infinity)
            }
        }
        .onKeyPress(.escape) {
            onDismiss()
            return .handled
        }
    }

    private func pinItem(_ item: ClipItem) {
        guard let firstPinboard = pinboards.first else { return }
        item.pinboard = firstPinboard
        persistence.save()
    }
}
