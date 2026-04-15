// Valt/UI/Views/ShelfView.swift
import SwiftUI
import CoreData

struct ShelfView: View {
    let persistence: PersistenceController
    @ObservedObject var selection: SelectionModel
    let onPaste: (ClipItem) -> Void
    let onCopy: (ClipItem) -> Void
    let onDismiss: () -> Void

    @State private var searchQuery = ""
    @State private var searchService: SearchService
    @State private var activeTab: ActiveTab = .history

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ClipItem.createdAt, ascending: false)],
        predicate: NSPredicate(format: "pinboard == nil"),
        animation: .default
    )
    private var historyItems: FetchedResults<ClipItem>

    init(
        persistence: PersistenceController,
        selection: SelectionModel,
        onPaste: @escaping (ClipItem) -> Void,
        onCopy: @escaping (ClipItem) -> Void,
        onDismiss: @escaping () -> Void
    ) {
        self.persistence = persistence
        self.selection = selection
        self.onPaste = onPaste
        self.onCopy = onCopy
        self.onDismiss = onDismiss
        _searchService = State(initialValue: SearchService(context: persistence.context))
    }

    private var displayedItems: [ClipItem] {
        guard searchQuery.isEmpty else { return searchService.results }
        switch activeTab {
        case .history:
            return Array(historyItems)
        case .pinboard(let pinboard):
            return pinboard.sortedItems
        }
    }

    var body: some View {
        VStack(spacing: 0) {
            // Barre d'onglets
            TabBarView(activeTab: $activeTab)
                .environment(\.managedObjectContext, persistence.context)
                .onChange(of: activeTab) { _, _ in
                    searchQuery = ""
                    selection.reset()
                }

            Divider()

            // Barre de recherche + engrenage
            HStack(spacing: 12) {
                SearchBarView(query: $searchQuery)
                    .onChange(of: searchQuery) { _, new in
                        searchService.search(new)
                        selection.reset()
                    }
                Spacer()
                Button {
                    onDismiss()
                    DispatchQueue.main.async {
                        (NSApp.delegate as? AppDelegate)?.openSettings()
                    }
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

            HistoryView(
                items: displayedItems,
                selection: selection,
                onPaste: onPaste,
                onCopy: onCopy,
                onPin: pinHandler
            )
            .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onChange(of: selection.pasteTrigger) { _, _ in
            guard selection.selectedIndex < displayedItems.count else { return }
            onPaste(displayedItems[selection.selectedIndex])
        }
        .onKeyPress(.escape) {
            onDismiss()
            return .handled
        }
    }

    // MARK: - Pin

    /// nil quand on est sur un onglet pinboard (le bouton est masqué)
    private var pinHandler: ((ClipItem) -> Void)? {
        guard case .history = activeTab else { return nil }
        return { item in pin(item) }
    }

    private func pin(_ item: ClipItem) {
        let ctx = persistence.context
        let req = Pinboard.fetchRequest()
        req.sortDescriptors = [NSSortDescriptor(keyPath: \Pinboard.position, ascending: true)]
        req.fetchLimit = 1
        guard let target = (try? ctx.fetch(req))?.first else { return }
        item.pinboard = target
        do { try ctx.save() } catch { print("[Valt] CoreData save failed: \(error)") }
    }
}
