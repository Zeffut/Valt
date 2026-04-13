// Valt/UI/Views/SelectionModel.swift
import Observation

/// État de sélection partagé entre PanelController (navigation clavier) et ShelfView (rendu + paste)
@Observable
final class SelectionModel {
    var selectedIndex: Int = 0
    var count: Int = 0
    /// Incrémenté par PanelController quand l'utilisateur appuie sur Entrée → ShelfView réagit et colle
    var pasteTrigger: Int = 0

    func moveLeft() {
        guard selectedIndex > 0 else { return }
        selectedIndex -= 1
    }

    func moveRight() {
        guard selectedIndex < count - 1 else { return }
        selectedIndex += 1
    }

    func triggerPaste() {
        pasteTrigger += 1
    }

    func reset() {
        selectedIndex = 0
    }
}
