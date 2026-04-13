// Valt/UI/Views/PreviewView.swift
import SwiftUI
import AppKit

// MARK: - Content type detection

enum ClipContent {
    case image
    case url(String)
    case color(Color, String)   // color + hex/css label
    case json(String)
    case code(String)
    case filePath(String)
    case email(String)
    case text(String)

    static func detect(item: ClipItem) -> ClipContent {
        switch item.type {
        case "image":
            return .image
        case "url":
            return .url(item.plainText ?? "")
        default:
            break
        }
        let text = item.plainText ?? ""

        // Hex color: #RGB, #RGBA, #RRGGBB, #RRGGBBAA
        if let color = Color(hexString: text) {
            return .color(color, text.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        // CSS rgb() / rgba()
        if let color = Color(cssString: text) {
            return .color(color, text.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        // Email
        let emailRegex = #"^[A-Z0-9a-z._%+\-]+@[A-Za-z0-9.\-]+\.[A-Za-z]{2,}$"#
        if text.trimmingCharacters(in: .whitespacesAndNewlines).range(of: emailRegex, options: .regularExpression) != nil {
            return .email(text.trimmingCharacters(in: .whitespacesAndNewlines))
        }
        // File path
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        if (trimmed.hasPrefix("/") || trimmed.hasPrefix("~/")) && !trimmed.contains("\n") && trimmed.count < 512 {
            return .filePath(trimmed)
        }
        // JSON
        if let data = text.data(using: .utf8),
           (try? JSONSerialization.jsonObject(with: data)) != nil,
           text.trimmingCharacters(in: .whitespaces).first.map({ $0 == "{" || $0 == "[" }) == true {
            return .json(text)
        }
        // Code heuristics
        if looksLikeCode(text) {
            return .code(text)
        }
        return .text(text)
    }

    private static func looksLikeCode(_ text: String) -> Bool {
        let codePatterns = [
            #"func\s+\w+\s*\("#,
            #"def\s+\w+\s*\("#,
            #"class\s+\w+[\s:{]"#,
            #"import\s+[\w.]+"#,
            #"const\s+\w+\s*="#,
            #"let\s+\w+\s*="#,
            #"var\s+\w+\s*="#,
            #"if\s*\(.+\)\s*\{"#,
            #"for\s*\(.+\)\s*\{"#,
            #"^\s*<\?xml"#,
            #"^\s*<html"#,
            #"->\s*\w+"#,
        ]
        for pattern in codePatterns {
            if text.range(of: pattern, options: [.regularExpression, .caseInsensitive]) != nil {
                return true
            }
        }
        // High density of special characters suggests code
        let specialChars = text.filter { "{}[]()<>=;:,|&!".contains($0) }
        return text.count > 20 && Double(specialChars.count) / Double(text.count) > 0.08
    }
}

// MARK: - Color extensions

extension Color {
    init?(hexString raw: String) {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines)
        guard s.hasPrefix("#") else { return nil }
        let hex = String(s.dropFirst())
        let count = hex.count
        guard count == 3 || count == 4 || count == 6 || count == 8 else { return nil }
        guard hex.allSatisfy({ $0.isHexDigit }) else { return nil }

        var full = hex
        if count == 3 || count == 4 {
            full = hex.map { "\($0)\($0)" }.joined()
        }
        guard let value = UInt64(full, radix: 16) else { return nil }
        let hasAlpha = full.count == 8
        let r, g, b, a: Double
        if hasAlpha {
            r = Double((value >> 24) & 0xFF) / 255
            g = Double((value >> 16) & 0xFF) / 255
            b = Double((value >> 8)  & 0xFF) / 255
            a = Double( value        & 0xFF) / 255
        } else {
            r = Double((value >> 16) & 0xFF) / 255
            g = Double((value >> 8)  & 0xFF) / 255
            b = Double( value        & 0xFF) / 255
            a = 1
        }
        self = Color(red: r, green: g, blue: b, opacity: a)
    }

    init?(cssString raw: String) {
        let s = raw.trimmingCharacters(in: .whitespacesAndNewlines).lowercased()
        let pattern = #"rgba?\(\s*(\d+)\s*,\s*(\d+)\s*,\s*(\d+)(?:\s*,\s*([\d.]+))?\s*\)"#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: s, range: NSRange(s.startIndex..., in: s)),
              match.numberOfRanges >= 4 else { return nil }
        func cap(_ i: Int) -> Double? {
            guard let range = Range(match.range(at: i), in: s) else { return nil }
            return Double(s[range])
        }
        guard let r = cap(1), let g = cap(2), let b = cap(3) else { return nil }
        let a = cap(4) ?? 1.0
        self = Color(red: r / 255, green: g / 255, blue: b / 255, opacity: a)
    }

    var isLight: Bool {
        guard let cgColor = NSColor(self).cgColor.converted(
            to: CGColorSpace(name: CGColorSpace.sRGB)!,
            intent: .defaultIntent,
            options: nil
        ) else { return true }
        let comps = cgColor.components ?? [0, 0, 0, 1]
        let luminance = 0.2126 * comps[0] + 0.7152 * comps[1] + 0.0722 * comps[2]
        return luminance > 0.5
    }
}

// MARK: - Main PreviewView

struct PreviewView: View {
    let item: ClipItem

    var body: some View {
        let content = ClipContent.detect(item: item)
        Group {
            switch content {
            case .image:
                ImagePreviewView(item: item)
            case .url(let urlString):
                URLPreviewView(urlString: urlString)
            case .color(let color, let label):
                ColorPreviewView(color: color, label: label)
            case .json(let text):
                CodePreviewView(text: text, language: "JSON")
            case .code(let text):
                CodePreviewView(text: text, language: nil)
            case .filePath(let path):
                FilePathPreviewView(path: path)
            case .email(let email):
                EmailPreviewView(email: email)
            case .text(let text):
                PlainTextPreviewView(text: text)
            }
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Sub-views

private struct PlainTextPreviewView: View {
    let text: String
    var body: some View {
        Text(text)
            .font(.system(size: 12))
            .lineLimit(8)
            .truncationMode(.tail)
            .foregroundStyle(.primary)
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
            .padding(10)
    }
}

private struct ImagePreviewView: View {
    let item: ClipItem
    var body: some View {
        Group {
            if let img = NSImage(data: item.content) {
                Image(nsImage: img)
                    .resizable()
                    .scaledToFill()
            } else {
                Image(systemName: "photo")
                    .font(.system(size: 24))
                    .foregroundStyle(.secondary)
            }
        }
        .clipped()
    }
}

private struct URLPreviewView: View {
    let urlString: String
    @State private var meta: URLMetadataStore.Metadata? = nil

    var body: some View {
        ZStack(alignment: .bottomLeading) {
            // Background: OG image or gradient
            if let ogImg = meta?.ogImage {
                Image(nsImage: ogImg)
                    .resizable()
                    .scaledToFill()
                    .clipped()
            } else {
                LinearGradient(
                    colors: [Color.blue.opacity(0.6), Color.purple.opacity(0.4)],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
            }

            // Bottom overlay
            VStack(alignment: .leading, spacing: 4) {
                HStack(spacing: 6) {
                    if let favicon = meta?.faviconImage {
                        Image(nsImage: favicon)
                            .resizable()
                            .frame(width: 14, height: 14)
                            .clipShape(RoundedRectangle(cornerRadius: 3))
                    } else {
                        Image(systemName: "globe")
                            .font(.system(size: 11))
                            .foregroundStyle(.white.opacity(0.8))
                    }
                    Text(meta?.domain ?? domainFallback)
                        .font(.system(size: 10, weight: .medium))
                        .foregroundStyle(.white.opacity(0.8))
                        .lineLimit(1)
                }
                if let title = meta?.title {
                    Text(title)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.white)
                        .lineLimit(2)
                } else {
                    Text(urlString)
                        .font(.system(size: 10))
                        .foregroundStyle(.white.opacity(0.7))
                        .lineLimit(2)
                        .truncationMode(.middle)
                }
            }
            .padding(8)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(.ultraThinMaterial.opacity(0.85))
        }
        .onAppear {
            URLMetadataStore.shared.fetchIfNeeded(urlString)
            meta = URLMetadataStore.shared.metadata(for: urlString)
        }
        .onChange(of: URLMetadataStore.shared.metadata(for: urlString)?.title) { _, _ in
            meta = URLMetadataStore.shared.metadata(for: urlString)
        }
        .onChange(of: URLMetadataStore.shared.metadata(for: urlString)?.faviconImage) { _, _ in
            meta = URLMetadataStore.shared.metadata(for: urlString)
        }
        .onChange(of: URLMetadataStore.shared.metadata(for: urlString)?.ogImage) { _, _ in
            meta = URLMetadataStore.shared.metadata(for: urlString)
        }
    }

    private var domainFallback: String {
        URL(string: urlString)?.host ?? urlString
    }
}

private struct ColorPreviewView: View {
    let color: Color
    let label: String

    var body: some View {
        ZStack {
            color
            VStack(spacing: 6) {
                RoundedRectangle(cornerRadius: 6)
                    .fill(color)
                    .frame(width: 48, height: 48)
                    .overlay(
                        RoundedRectangle(cornerRadius: 6)
                            .stroke(color.isLight ? Color.black.opacity(0.2) : Color.white.opacity(0.3), lineWidth: 1)
                    )
                Text(label)
                    .font(.system(size: 11, weight: .medium, design: .monospaced))
                    .foregroundStyle(color.isLight ? Color.black.opacity(0.8) : Color.white.opacity(0.9))
            }
        }
    }
}

private struct CodePreviewView: View {
    let text: String
    let language: String?

    var body: some View {
        ZStack(alignment: .topLeading) {
            Color.black.opacity(0.6)
            VStack(alignment: .leading, spacing: 4) {
                if let lang = language {
                    Text(lang)
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.5))
                        .padding(.horizontal, 10)
                        .padding(.top, 8)
                }
                Text(text)
                    .font(.system(size: 10, design: .monospaced))
                    .foregroundStyle(Color(red: 0.6, green: 0.9, blue: 0.6))
                    .lineLimit(10)
                    .truncationMode(.tail)
                    .padding(.horizontal, 10)
                    .padding(.bottom, 8)
                    .padding(.top, language == nil ? 8 : 2)
            }
        }
    }
}

private struct FilePathPreviewView: View {
    let path: String

    private var components: [String] {
        path.components(separatedBy: "/").filter { !$0.isEmpty }
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.system(size: 24))
                .foregroundStyle(.secondary)

            VStack(alignment: .leading, spacing: 2) {
                if let last = components.last {
                    Text(last)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                }
                Text(path)
                    .font(.system(size: 9, design: .monospaced))
                    .foregroundStyle(.secondary)
                    .lineLimit(2)
                    .truncationMode(.middle)
            }
        }
        .padding(10)
        .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .topLeading)
    }

    private var icon: String {
        let ext = path.components(separatedBy: ".").last?.lowercased() ?? ""
        switch ext {
        case "pdf": return "doc.richtext"
        case "png", "jpg", "jpeg", "gif", "webp", "heic": return "photo"
        case "mp4", "mov", "avi": return "film"
        case "mp3", "wav", "aac", "m4a": return "music.note"
        case "zip", "tar", "gz", "rar": return "archivebox"
        case "swift", "py", "js", "ts", "rb", "go", "rs": return "doc.text"
        case "app", "dmg", "pkg": return "app.badge"
        default: return "folder"
        }
    }
}

private struct EmailPreviewView: View {
    let email: String

    var body: some View {
        VStack(spacing: 8) {
            Image(systemName: "envelope.fill")
                .font(.system(size: 28))
                .foregroundStyle(.blue)
            Text(email)
                .font(.system(size: 11))
                .foregroundStyle(.primary)
                .lineLimit(2)
                .multilineTextAlignment(.center)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(10)
    }
}
