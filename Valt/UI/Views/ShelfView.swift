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
    let onTogglePin: (ClipItem) -> Void
    let onDeleteTrigger: ([ClipItem]) -> Void

    @FetchRequest private var items: FetchedResults<ClipItem>

    init(
        pinboard: Pinboard,
        persistence: PersistenceController,
        selection: SelectionModel,
        onPaste: @escaping (ClipItem) -> Void,
        onCopy: @escaping (ClipItem) -> Void,
        onTogglePin: @escaping (ClipItem) -> Void,
        onDeleteTrigger: @escaping ([ClipItem]) -> Void
    ) {
        self.persistence = persistence
        self.selection = selection
        self.onPaste = onPaste
        self.onCopy = onCopy
        self.onTogglePin = onTogglePin
        self.onDeleteTrigger = onDeleteTrigger
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
            onTogglePin: onTogglePin
        )
        .onChange(of: items.count) { _, count in
            selection.count = count
        }
        .onChange(of: selection.favoriteTrigger) { _, _ in
            guard selection.selectedIndex < items.count else { return }
            onTogglePin(items[selection.selectedIndex])
        }
        .onChange(of: selection.deleteTrigger) { _, _ in
            onDeleteTrigger(Array(items))
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
    @State private var isCreatingTab = false
    @State private var mouseMonitor: Any?

    @FetchRequest(
        sortDescriptors: [NSSortDescriptor(keyPath: \ClipItem.createdAt, ascending: false)],
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
                TabBarView(activeTab: $activeTab, isCreating: $isCreatingTab, onDropItem: { url, pinboard in
                    handleDrop(uri: url, targetPinboard: pinboard)
                })
                .environment(\.managedObjectContext, persistence.context)
                    .onChange(of: activeTab) { _, tab in
                        searchQuery = ""
                        selection.reset()
                        // Sync tabIndex ← clic sur onglet
                        let idx: Int
                        switch tab {
                        case .history: idx = 0
                        case .pinboard(let pb):
                            idx = (pinboards.firstIndex(of: pb) ?? -1) + 1
                        }
                        if selection.tabIndex != idx { selection.tabIndex = idx }
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
        // Synchronise tabCount pour la navigation clavier haut/bas
        .onAppear {
            selection.tabCount = 1 + pinboards.count
        }
        .onChange(of: pinboards.count) { _, count in
            selection.tabCount = 1 + count
        }
        // tabIndex → activeTab (navigation clavier)
        .onChange(of: selection.tabIndex) { _, idx in
            let target: ActiveTab = idx == 0
                ? .history
                : (idx - 1 < pinboards.count ? .pinboard(pinboards[idx - 1]) : .history)
            guard activeTab != target else { return }
            activeTab = target
        }
        .onKeyPress(.escape) {
            onDismiss()
            return .handled
        }
        .onChange(of: isCreatingTab) { _, creating in
            if creating {
                mouseMonitor = NSEvent.addLocalMonitorForEvents(matching: .leftMouseDown) { event in
                    // Laisse l'événement passer normalement, annule juste la création
                    isCreatingTab = false
                    return event
                }
            } else {
                if let m = mouseMonitor { NSEvent.removeMonitor(m); mouseMonitor = nil }
            }
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
                onTogglePin: { item in togglePin(item) }
            )
            // .id force SwiftUI à créer une instance fraîche de HistoryView (et donc
            // du ScrollView) à chaque reset → scroll offset 0 garanti, sans état préservé.
            .id(selection.resetToken)
            .onChange(of: selection.pasteTrigger) { _, _ in
                guard selection.selectedIndex < items.count else { return }
                onPaste(items[selection.selectedIndex])
            }
            .onChange(of: selection.favoriteTrigger) { _, _ in
                guard selection.selectedIndex < items.count else { return }
                togglePin(items[selection.selectedIndex])
            }
            .onChange(of: selection.deleteTrigger) { _, _ in
                guard selection.selectedIndex < items.count else { return }
                deleteItem(items[selection.selectedIndex])
            }

        case .pinboard(let pb):
            PinnedItemsView(
                pinboard: pb,
                persistence: persistence,
                selection: selection,
                onPaste: onPaste,
                onCopy: onCopy,
                onTogglePin: { item in togglePin(item) },
                onDeleteTrigger: { items in
                    guard selection.selectedIndex < items.count else { return }
                    deleteItem(items[selection.selectedIndex])
                }
            )
        }
    }

    // MARK: - Toggle pin

    private func togglePin(_ item: ClipItem) {
        let ctx = persistence.context
        if item.pinboard != nil {
            item.pinboard = nil
        } else {
            let req = Pinboard.fetchRequest()
            req.sortDescriptors = [NSSortDescriptor(keyPath: \Pinboard.position, ascending: true)]
            req.fetchLimit = 1
            guard let target = (try? ctx.fetch(req))?.first else { return }
            item.pinboard = target
        }
        do { try ctx.save() } catch { print("[Valt] CoreData save failed: \(error)") }
    }

    // MARK: - Delete

    private func deleteItem(_ item: ClipItem) {
        // Ne pas supprimer le dernier élément — le presse-papier est toujours rempli
        let req = ClipItem.fetchRequest()
        guard let total = try? persistence.context.count(for: req), total > 1 else { return }
        persistence.context.delete(item)
        do { try persistence.context.save() } catch { print("[Valt] CoreData save failed: \(error)") }
    }

    // MARK: - Drag & drop

    private func handleDrop(uri: URL, targetPinboard: Pinboard?) {
        let ctx = persistence.context
        guard let coordinator = ctx.persistentStoreCoordinator,
              let objectID = coordinator.managedObjectID(forURIRepresentation: uri),
              let item = try? ctx.existingObject(with: objectID) as? ClipItem else { return }
        item.pinboard = targetPinboard
        do { try ctx.save() } catch { print("[Valt] CoreData save failed: \(error)") }
    }
}
