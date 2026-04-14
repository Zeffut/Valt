// Valt/Services/SearchService.swift
import CoreData
import Observation

@MainActor
@Observable
final class SearchService {
    private(set) var results: [ClipItem] = []
    private(set) var query: String = ""

    private let mainContext: NSManagedObjectContext
    private let bgContext: NSManagedObjectContext
    private var debounceTask: Task<Void, Never>?

    init(context: NSManagedObjectContext) {
        self.mainContext = context
        // Contexte dédié pour les fetches — ne bloque pas le MainActor
        self.bgContext = context.newBackgroundContext()
        self.bgContext.automaticallyMergesChangesFromParent = true
    }

    func search(_ text: String) {
        query = text
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            await self.performSearch(text)
        }
    }

    func clear() {
        query = ""
        results = []
        debounceTask?.cancel()
    }

    private func performSearch(_ text: String) async {
        let ctx = bgContext
        let objectIDs: [NSManagedObjectID] = await Task.detached {
            var ids: [NSManagedObjectID] = []
            ctx.performAndWait {
                let req = NSFetchRequest<NSManagedObjectID>(entityName: "ClipItem")
                req.resultType = .managedObjectIDResultType
                req.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
                req.fetchLimit = 200
                req.predicate = text.isEmpty
                    ? NSPredicate(format: "pinboard == nil")
                    : NSPredicate(format: "plainText CONTAINS[cd] %@ AND pinboard == nil", text)
                ids = (try? ctx.fetch(req)) ?? []
            }
            return ids
        }.value

        // Réhydrater les objets sur le MainActor depuis le context principal
        guard !Task.isCancelled else { return }
        results = objectIDs.compactMap {
            try? mainContext.existingObject(with: $0) as? ClipItem
        }
    }
}

extension NSManagedObjectContext {
    func newBackgroundContext() -> NSManagedObjectContext {
        let ctx = NSManagedObjectContext(concurrencyType: .privateQueueConcurrencyType)
        ctx.parent = self
        return ctx
    }
}
