// Valt/UI/Views/SelectionModel.swift
import Combine

final class SelectionModel: ObservableObject {
    @Published var selectedIndex: Int = 0
    @Published var count: Int = 0
    @Published var pasteTrigger: Int = 0
    @Published var resetToken: Int = 0

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
        resetToken += 1
    }
}
