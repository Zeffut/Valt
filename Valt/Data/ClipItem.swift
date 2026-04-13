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

    /// Supprime les anciens clips hors pinboard au-delà de `limit`
    static func purgeOldItems(keeping limit: Int, in context: NSManagedObjectContext) {
        let req = fetchRequest()
        req.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        req.predicate = NSPredicate(format: "pinboard == nil")
        guard let items = try? context.fetch(req), items.count > limit else { return }
        items.dropFirst(limit).forEach { context.delete($0) }
        try? context.save()
    }
}
