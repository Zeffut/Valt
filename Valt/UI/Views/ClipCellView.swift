// Valt/UI/Views/ClipCellView.swift
import SwiftUI
import AppKit

struct ClipCellView: View {
    let item: ClipItem
    let onPaste: () -> Void
    let onCopy: () -> Void
    let onPin: (() -> Void)?

    @State private var isHovered = false

    private let cellWidth: CGFloat = 160
    private let cellHeight: CGFloat = 160

    var body: some View {
        VStack(spacing: 0) {
            PreviewView(item: item)
                .frame(width: cellWidth, height: cellHeight - 36)
                .clipped()

            HStack(spacing: 4) {
                appIcon
                Text(relativeDate)
                    .font(.system(size: 10))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
                Spacer()
            }
            .padding(.horizontal, 8)
            .frame(height: 36)
            .background(.ultraThinMaterial)
        }
        .frame(width: cellWidth, height: cellHeight)
        .background(isHovered ? Color.accentColor.opacity(0.15) : Color.clear)
        .clipShape(RoundedRectangle(cornerRadius: 8))
        .overlay(
            RoundedRectangle(cornerRadius: 8)
                .stroke(isHovered ? Color.accentColor : Color.white.opacity(0.1), lineWidth: 1)
        )
        .onHover { isHovered = $0 }
        .onTapGesture(count: 2) { onCopy() }
        .onTapGesture(count: 1) { onPaste() }
        .contextMenu {
            Button("Copier") { onCopy() }
            Button("Coller") { onPaste() }
            if let onPin {
                Divider()
                Button("Épingler") { onPin() }
            }
        }
    }

    private var appIcon: some View {
        Group {
            if let bundleID = item.sourceApp,
               let url = NSWorkspace.shared.urlForApplication(withBundleIdentifier: bundleID) {
                let icon = NSWorkspace.shared.icon(forFile: url.path)
                Image(nsImage: icon)
                    .resizable()
                    .frame(width: 14, height: 14)
            } else {
                Image(systemName: "doc.on.clipboard")
                    .frame(width: 14, height: 14)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private var relativeDate: String {
        let formatter = RelativeDateTimeFormatter()
        formatter.unitsStyle = .abbreviated
        return formatter.localizedString(for: item.createdAt, relativeTo: Date())
    }
}
