// Valt/Data/ClipItem.swift
import CoreData

@objc(ClipItem)
final class ClipItem: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var content: Data
    @NSManaged var type: String       // "text" | "url" | "image" | "file"
    @NSManaged var plainText: String?
    @NSManaged var sourceApp: String?
    @NSManaged var sourceAppName: String?
    @NSManaged var createdAt: Date
    @NSManaged var pinboard: Pinboard?

    @nonobjc class func fetchRequest() -> NSFetchRequest<ClipItem> {
        NSFetchRequest<ClipItem>(entityName: "ClipItem")
    }

    static func create(
        content: Data,
        type: String,
        plainText: String?,
        sourceApp: String?,
        sourceAppName: String?,
        in context: NSManagedObjectContext
    ) -> ClipItem {
        let item = ClipItem(context: context)
        item.id = UUID()
        item.content = content
        item.type = type
        item.plainText = plainText
        item.sourceApp = sourceApp
        item.sourceAppName = sourceAppName
        item.createdAt = Date()
        return item
    }

    /// Renvoie le dernier clip hors pinboard, ou nil
    static func fetchLatest(in context: NSManagedObjectContext) -> ClipItem? {
        let req = fetchRequest()
        req.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        req.predicate = NSPredicate(format: "pinboard == nil")
        req.fetchLimit = 1
        return try? context.fetch(req).first
    }

    /// Supprime les anciens clips hors pinboard au-delà de `limit` via NSBatchDeleteRequest.
    /// N'appelle PAS save() — c'est à l'appelant de le faire.
    static func purgeOldItems(keeping limit: Int, in context: NSManagedObjectContext) {
        // Compter d'abord pour éviter un fetch inutile
        let countReq = fetchRequest()
        countReq.predicate = NSPredicate(format: "pinboard == nil")
        guard let total = try? context.count(for: countReq), total > limit else { return }

        // Récupérer uniquement les IDs des items à conserver (les plus récents)
        let keepReq = fetchRequest()
        keepReq.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        keepReq.predicate = NSPredicate(format: "pinboard == nil")
        keepReq.fetchLimit = limit
        keepReq.resultType = .managedObjectIDResultType
        guard let keepIDs = try? context.fetch(keepReq) as? [NSManagedObjectID] else { return }

        // Supprimer tout ce qui n'est pas dans la liste des IDs à conserver
        let deleteReq = NSFetchRequest<NSFetchRequestResult>(entityName: "ClipItem")
        deleteReq.predicate = NSCompoundPredicate(andPredicateWithSubpredicates: [
            NSPredicate(format: "pinboard == nil"),
            NSPredicate(format: "NOT (self IN %@)", keepIDs)
        ])
        let batchDelete = NSBatchDeleteRequest(fetchRequest: deleteReq)
        batchDelete.resultType = .resultTypeObjectIDs
        if let result = try? context.execute(batchDelete) as? NSBatchDeleteResult,
           let deleted = result.result as? [NSManagedObjectID] {
            NSManagedObjectContext.mergeChanges(
                fromRemoteContextSave: [NSDeletedObjectsKey: deleted],
                into: [context]
            )
        }
    }
}
