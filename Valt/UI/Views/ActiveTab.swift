// Valt/UI/Views/ActiveTab.swift
import Foundation

enum ActiveTab: Equatable {
    case history
    case pinboard(Pinboard)

    static func == (lhs: ActiveTab, rhs: ActiveTab) -> Bool {
        switch (lhs, rhs) {
        case (.history, .history): return true
        case (.pinboard(let a), .pinboard(let b)): return a.id == b.id
        default: return false
        }
    }
}
