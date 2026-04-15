// Valt/UI/Views/ClipCellView.swift
import SwiftUI
import AppKit

struct ClipCellView: View {
    let item: ClipItem
    let isSelected: Bool
    let onPaste: () -> Void
    let onCopy: () -> Void
    let onPin: (() -> Void)?
    let onUnpin: (() -> Void)?

    @State private var isHovered = false

    private let cellWidth: CGFloat = 220
    private let cellHeight: CGFloat = 215

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
        .background(
            isSelected
                ? Color.accentColor.opacity(0.25)
                : (isHovered ? Color.white.opacity(0.08) : Color.clear)
        )
        .clipShape(RoundedRectangle(cornerRadius: 10))
        .overlay(
            RoundedRectangle(cornerRadius: 10)
                .stroke(
                    isSelected ? Color.accentColor : Color.white.opacity(0.12),
                    lineWidth: isSelected ? 2 : 1
                )
        )
        .shadow(color: isSelected ? Color.accentColor.opacity(0.3) : .clear, radius: 6)
        .overlay(alignment: .topTrailing) {
            if isHovered, onPin != nil || onUnpin != nil {
                Button(action: { onUnpin?() ?? onPin?() ?? () }) {
                    Image(systemName: onUnpin != nil ? "pin.slash.fill" : "pin.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(onUnpin != nil ? Color.secondary : Color.accentColor)
                        .clipShape(Circle())
                }
                .buttonStyle(.plain)
                .padding(6)
                .transition(.opacity.combined(with: .scale))
            }
        }
        .animation(.easeInOut(duration: 0.15), value: isHovered)
        .onHover { isHovered = $0 }
        .onTapGesture(count: 2) { onCopy() }
        .onTapGesture(count: 1) { onPaste() }
        .contextMenu {
            Button("Coller") { onPaste() }
            Button("Copier") { onCopy() }
            if let onUnpin {
                Divider()
                Button("Retirer du pinboard") { onUnpin() }
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
