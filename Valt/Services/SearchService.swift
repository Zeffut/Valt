// Valt/Services/SearchService.swift
import CoreData
import Observation

@MainActor
@Observable
final class SearchService {
    private(set) var results: [ClipItem] = []
    private(set) var query: String = ""

    private let context: NSManagedObjectContext
    private var debounceTask: Task<Void, Never>?

    init(context: NSManagedObjectContext) {
        self.context = context
    }

    func search(_ text: String) {
        query = text
        debounceTask?.cancel()
        debounceTask = Task {
            try? await Task.sleep(for: .milliseconds(150))
            guard !Task.isCancelled else { return }
            self.performSearch(text)
        }
    }

    func clear() {
        query = ""
        results = []
        debounceTask?.cancel()
    }

    private func performSearch(_ text: String) {
        let req = ClipItem.fetchRequest()
        req.sortDescriptors = [NSSortDescriptor(key: "createdAt", ascending: false)]
        req.fetchLimit = 200
        if !text.isEmpty {
            req.predicate = NSPredicate(format: "plainText CONTAINS[cd] %@ AND pinboard == nil", text)
        } else {
            req.predicate = NSPredicate(format: "pinboard == nil")
        }
        results = (try? context.fetch(req)) ?? []
    }
}
