// Valt/UI/Views/ClipCellView.swift
import SwiftUI
import AppKit
import UniformTypeIdentifiers

struct ClipCellView: View {
    @ObservedObject var item: ClipItem
    let isSelected: Bool
    let onPaste: () -> Void
    let onCopy: () -> Void
    let onTogglePin: (() -> Void)?

    @State private var isHovered = false

    private let cellWidth: CGFloat = 220
    private let cellHeight: CGFloat = 215

    private var isValid: Bool { !item.isDeleted && item.managedObjectContext != nil }
    private var isPinned: Bool { item.pinboard != nil }

    var body: some View {
        Group {
            if isValid {
                content
            }
        }
    }

    @ViewBuilder
    private var content: some View {
        VStack(spacing: 0) {
            PreviewView(item: item)
                .frame(width: cellWidth, height: cellHeight - 36)
                .clipped()

            HStack(spacing: 4) {
                Image(systemName: typeIcon)
                    .font(.system(size: 10))
                    .foregroundStyle(.tertiary)
                    .frame(width: 14)
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
            if let onTogglePin, isHovered || isSelected {
                Button(action: onTogglePin) {
                    Image(systemName: isPinned ? "pin.slash.fill" : "pin.fill")
                        .font(.system(size: 10))
                        .foregroundStyle(.white)
                        .padding(6)
                        .background(isPinned ? Color.secondary : Color.accentColor)
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
            if let onTogglePin {
                Divider()
                Button(isPinned ? "Retirer des favoris" : "Ajouter aux favoris") {
                    onTogglePin()
                }
            }
        }
        .onDrag {
            let uri = item.objectID.uriRepresentation()
            return NSItemProvider(object: uri as NSURL)
        }
    }

    // MARK: - Helpers

    private var typeIcon: String {
        switch item.type {
        case "image": return "photo"
        case "url":   return "globe"
        default:
            let t = item.plainText?.trimmingCharacters(in: .whitespacesAndNewlines) ?? ""
            if t.hasPrefix("#") { return "paintpalette" }
            if t.hasPrefix("{") || t.hasPrefix("[") { return "curlybraces" }
            if t.hasPrefix("/") || t.hasPrefix("~/") { return "folder" }
            if t.contains("@") && t.contains(".") && !t.contains(" ") { return "envelope" }
            if looksLikeCode(t) { return "chevron.left.forwardslash.chevron.right" }
            return "doc.text"
        }
    }

    private func looksLikeCode(_ text: String) -> Bool {
        let specials = text.filter { "{}[]()<>;".contains($0) }
        return text.count > 20 && Double(specials.count) / Double(text.count) > 0.06
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
