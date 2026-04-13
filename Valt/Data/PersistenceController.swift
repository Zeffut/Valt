// Valt/Data/PersistenceController.swift
import CoreData

@MainActor
final class PersistenceController {
    static let shared = PersistenceController()

    let container: NSPersistentContainer

    var context: NSManagedObjectContext { container.viewContext }

    private init() {
        container = NSPersistentContainer(name: "Valt", managedObjectModel: .valt)
        container.loadPersistentStores { _, error in
            if let error { fatalError("Core Data load failed: \(error)") }
        }
        container.viewContext.automaticallyMergesChangesFromParent = true
        container.viewContext.mergePolicy = NSMergePolicy(merge: .mergeByPropertyObjectTrumpMergePolicyType)

        ensureDefaultPinboard()
    }

    private func ensureDefaultPinboard() {
        let req = Pinboard.fetchRequest()
        let count = (try? context.count(for: req)) ?? 0
        guard count == 0 else { return }
        _ = Pinboard.createDefault(in: context)
        try? context.save()
    }

    func save() {
        guard context.hasChanges else { return }
        try? context.save()
    }
}
