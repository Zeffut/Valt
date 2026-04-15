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

    /// Renvoie le dernier clip (épinglé ou non) pour la déduplication.
    static func fetchLatest(in context: NSManagedObjectContext) -> ClipItem? {
        let req = fetchRequest()
        req.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        req.fetchLimit = 1
        return try? context.fetch(req).first
    }

    /// Supprime les clips hors pinboard au-delà de `limit` et/ou plus vieux que `days` jours.
    /// N'appelle PAS save() — c'est à l'appelant de le faire.
    static func purgeOldItems(keeping limit: Int, olderThan days: Int = 0, in context: NSManagedObjectContext) {
        let req = fetchRequest()
        req.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        req.predicate = NSPredicate(format: "pinboard == nil")
        guard let items = try? context.fetch(req) else { return }

        // Suppression par ancienneté
        if days > 0 {
            let cutoff = Date().addingTimeInterval(-Double(days) * 86_400)
            items.filter { $0.createdAt < cutoff }.forEach { context.delete($0) }
        }

        // Suppression par nombre (sur ce qui reste après la purge par date)
        let remaining = items.filter { !context.deletedObjects.contains($0) }
        if remaining.count > limit {
            remaining.dropFirst(limit).forEach { context.delete($0) }
        }
    }
}
