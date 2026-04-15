// Valt/UI/Views/SelectionModel.swift
import Combine

final class SelectionModel: ObservableObject {
    @Published var selectedIndex: Int = 0
    @Published var count: Int = 0
    @Published var pasteTrigger: Int = 0
    @Published var favoriteTrigger: Int = 0
    @Published var deleteTrigger: Int = 0
    @Published var resetToken: Int = 0

    // Navigation entre onglets (0 = Historique, 1+ = pinboards)
    @Published var tabIndex: Int = 0
    var tabCount: Int = 1

    func moveLeft() {
        guard selectedIndex > 0 else { return }
        selectedIndex -= 1
    }

    func moveRight() {
        guard selectedIndex < count - 1 else { return }
        selectedIndex += 1
    }

    func moveTabUp() {
        tabIndex = tabIndex == 0 ? tabCount - 1 : tabIndex - 1
    }

    func moveTabDown() {
        tabIndex = tabIndex == tabCount - 1 ? 0 : tabIndex + 1
    }

    func triggerPaste() {
        pasteTrigger += 1
    }

    func triggerFavorite() {
        favoriteTrigger += 1
    }

    func triggerDelete() {
        deleteTrigger += 1
    }

    func reset() {
        selectedIndex = 0
        tabIndex = 0
        resetToken += 1
    }
}
