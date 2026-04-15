// Valt/UI/Panel/PastePanel.swift
import AppKit

final class PastePanel: NSPanel {
    static let panelHeight: CGFloat = 320

    init() {
        let screen = NSScreen.main ?? NSScreen.screens[0]
        let frame = CGRect(
            x: screen.frame.origin.x,
            y: screen.frame.origin.y,
            width: screen.frame.width,
            height: Self.panelHeight
        )

        super.init(
            contentRect: frame,
            styleMask: [.nonactivatingPanel, .fullSizeContentView, .borderless],
            backing: .buffered,
            defer: false
        )

        isFloatingPanel = true
        level = .floating
        isOpaque = false
        backgroundColor = .clear
        hasShadow = true
        isMovable = false
        hidesOnDeactivate = false
        collectionBehavior = [.canJoinAllSpaces, .fullScreenAuxiliary]

        let visual = NSVisualEffectView(frame: .zero)
        visual.material = .hudWindow
        visual.blendingMode = .behindWindow
        visual.state = .active
        visual.wantsLayer = true
        visual.layer?.cornerRadius = 12
        visual.layer?.maskedCorners = [.layerMinXMaxYCorner, .layerMaxXMaxYCorner]
        contentView = visual
    }

    override var canBecomeKey: Bool { true }
    override var canBecomeMain: Bool { false }
}
