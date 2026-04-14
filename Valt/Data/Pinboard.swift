// Valt/Data/Pinboard.swift
import CoreData

@objc(Pinboard)
final class Pinboard: NSManagedObject {
    @NSManaged var id: UUID
    @NSManaged var name: String
    @NSManaged var position: Int16
    @NSManaged var items: NSSet?

    @nonobjc class func fetchRequest() -> NSFetchRequest<Pinboard> {
        NSFetchRequest<Pinboard>(entityName: "Pinboard")
    }

    var sortedItems: [ClipItem] {
        (items as? Set<ClipItem> ?? []).sorted { $0.createdAt > $1.createdAt }
    }

    static func createDefault(in context: NSManagedObjectContext) -> Pinboard {
        let pb = Pinboard(context: context)
        pb.id = UUID()
        pb.name = "Favoris"
        pb.position = 0
        return pb
    }

    static func create(name: String, in context: NSManagedObjectContext) -> Pinboard {
        let pb = Pinboard(context: context)
        pb.id = UUID()
        pb.name = name
        pb.position = Int16((try? context.count(for: fetchRequest())) ?? 0)
        return pb
    }
}
