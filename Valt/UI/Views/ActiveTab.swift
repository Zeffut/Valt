// Valt/UI/Views/ActiveTab.swift
import CoreData

enum ActiveTab: Equatable, Hashable {
    case history
    case pinboard(Pinboard)

    static func == (lhs: ActiveTab, rhs: ActiveTab) -> Bool {
        switch (lhs, rhs) {
        case (.history, .history): return true
        case (.pinboard(let a), .pinboard(let b)): return a.id == b.id
        default: return false
        }
    }

    func hash(into hasher: inout Hasher) {
        switch self {
        case .history:
            hasher.combine(0)
        case .pinboard(let pb):
            hasher.combine(1)
            hasher.combine(pb.id)
        }
    }
}
