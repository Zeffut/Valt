// Valt/UI/Views/ShelfView.swift
import SwiftUI
import CoreData

// MARK: - PinnedItemsView

/// Sous-vue dédiée aux items d'un pinboard.
/// Crée son propre @FetchRequest avec le prédicat fixé à l'init,
/// ce qui garantit que les données sont correctes dès le premier rendu
/// (contrairement à nsPredicate mis à jour dans onChange, qui s'exécute après).
private struct PinnedItemsView: View {
    let persistence: PersistenceController
    @ObservedObject var selection: SelectionModel
    let onPaste: (ClipItem) -> Void
    let onCopy: (ClipItem) -> Void
    let onUnpin: (ClipItem) -> Void

    @FetchRequest private var items: FetchedResults<ClipItem>

    init(
        pinboard: Pinboard,
        persistence: PersistenceController,
        selection: SelectionModel,
        onPaste: @escaping (ClipItem) -> Void,
        onCopy: @escaping (ClipItem) -> Void,
        onUnpin: @escaping (ClipItem) -> Void
    ) {
        self.persistence = persistence
        self.selection = selection
        self.onPaste = onPaste
        self.onCopy = onCopy
        self.onUnpin = onUnpin
        _items = FetchRequest(
            sortDescriptors: [NSSortDescriptor(keyPath: \ClipItem.createdAt, ascending: false)],
            predicate: NSPredicate(format: "pinboard == %@", pinboard),
            animation: .default
        )
    }

    var body: some View {
        HistoryView(
            items: Array(items),
            selection: selection,
            onPaste: onPaste,
            onCopy: onCopy,
            onPin: nil,
            onUnpin: onUnpin
        )
        .onChange(of: items.count) { _, count in
            selection.count = count
        }
    }
}

// MARK: - ShelfView

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

    var body: some View {
        VStack(spacing: 0) {
            // Header : onglets + recherche
            VStack(spacing: 0) {
                TabBarView(activeTab: $activeTab)
                    .environment(\.managedObjectContext, persistence.context)
                    .onChange(of: activeTab) { _, _ in
                        searchQuery = ""
                        selection.reset()
                    }

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
            }
            .background(.ultraThinMaterial)

            Divider()

            contentView
                .frame(maxWidth: .infinity, maxHeight: .infinity)
        }
        .onChange(of: historyItems.count) { _, count in
            if case .history = activeTab, searchQuery.isEmpty {
                selection.count = count
            }
        }
        .onKeyPress(.escape) {
            onDismiss()
            return .handled
        }
    }

    // MARK: - Content routing

    @ViewBuilder
    private var contentView: some View {
        switch activeTab {
        case .history:
            let items = searchQuery.isEmpty ? Array(historyItems) : searchService.results
            HistoryView(
                items: items,
                selection: selection,
                onPaste: onPaste,
                onCopy: onCopy,
                onPin: { item in pin(item) },
                onUnpin: nil
            )
            .onChange(of: selection.pasteTrigger) { _, _ in
                guard selection.selectedIndex < items.count else { return }
                onPaste(items[selection.selectedIndex])
            }

        case .pinboard(let pb):
            PinnedItemsView(
                pinboard: pb,
                persistence: persistence,
                selection: selection,
                onPaste: onPaste,
                onCopy: onCopy,
                onUnpin: { item in
                    item.pinboard = nil
                    do { try persistence.context.save() } catch { print("[Valt] CoreData save failed: \(error)") }
                }
            )
        }
    }

    // MARK: - Pin

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
