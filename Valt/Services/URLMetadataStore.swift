// Valt/Services/URLMetadataStore.swift
import AppKit
import Observation
import CryptoKit

@Observable
@MainActor
final class URLMetadataStore {
    static let shared = URLMetadataStore()

    struct Metadata {
        var title: String?
        var domain: String
        var faviconImage: NSImage?
        var ogImage: NSImage?
    }

    private var cache: [String: Metadata] = [:]
    private var fetching: Set<String> = []

    private static let udKey = "valt.urlCache"
    private static let maxHTMLBytes = 512 * 1024

    // Dossier ~/Library/Caches/com.valt.app/urlImages/
    private static let imagesCacheDir: URL = {
        let base = FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask)[0]
        let dir = base.appendingPathComponent("com.valt.app/urlImages", isDirectory: true)
        try? FileManager.default.createDirectory(at: dir, withIntermediateDirectories: true)
        return dir
    }()

    private init() { loadPersistedCache() }

    func metadata(for urlString: String) -> Metadata? { cache[urlString] }

    func fetchIfNeeded(_ urlString: String) {
        guard cache[urlString] == nil, !fetching.contains(urlString) else { return }
        guard let url = URL(string: urlString) else { return }
        fetching.insert(urlString)
        Task {
            let meta = await Self.fetch(url: url, urlString: urlString)
            self.cache[urlString] = meta
            self.fetching.remove(urlString)
            self.persistCache(urlString: urlString, meta: meta)
        }
    }

    // MARK: - Persistance texte (UserDefaults) + images (fichiers)

    private func loadPersistedCache() {
        guard let dict = UserDefaults.standard.dictionary(forKey: Self.udKey) as? [String: [String: String]] else { return }
        for (urlString, entry) in dict {
            guard let domain = entry["domain"] else { continue }
            var meta = Metadata(title: entry["title"], domain: domain)
            let key = Self.cacheKey(for: urlString)
            meta.faviconImage = Self.loadImage(name: "\(key)_favicon")
            meta.ogImage      = Self.loadImage(name: "\(key)_og")
            cache[urlString] = meta
        }
    }

    private func persistCache(urlString: String, meta: Metadata) {
        // Texte → UserDefaults
        var dict = (UserDefaults.standard.dictionary(forKey: Self.udKey) as? [String: [String: String]]) ?? [:]
        var entry: [String: String] = ["domain": meta.domain]
        if let title = meta.title { entry["title"] = title }
        dict[urlString] = entry
        UserDefaults.standard.set(dict, forKey: Self.udKey)

        // Images → fichiers PNG
        let key = Self.cacheKey(for: urlString)
        if let img = meta.faviconImage { Self.saveImage(img, name: "\(key)_favicon") }
        if let img = meta.ogImage      { Self.saveImage(img, name: "\(key)_og") }
    }

    // MARK: - Image I/O

    private static func cacheKey(for urlString: String) -> String {
        let data = Data(urlString.utf8)
        let hash = SHA256.hash(data: data)
        return hash.prefix(16).map { String(format: "%02x", $0) }.joined()
    }

    private static func saveImage(_ image: NSImage, name: String) {
        guard let tiff = image.tiffRepresentation,
              let bitmap = NSBitmapImageRep(data: tiff),
              let png = bitmap.representation(using: .png, properties: [:]) else { return }
        let url = imagesCacheDir.appendingPathComponent("\(name).png")
        try? png.write(to: url, options: .atomic)
    }

    private static func loadImage(name: String) -> NSImage? {
        let url = imagesCacheDir.appendingPathComponent("\(name).png")
        guard FileManager.default.fileExists(atPath: url.path),
              let img = NSImage(contentsOf: url) else { return nil }
        return img
    }

    // MARK: - Fetching

    private static func fetch(url: URL, urlString: String) async -> Metadata {
        let domain = url.host ?? urlString
        var meta = Metadata(domain: domain)

        // Favicon via Google S2
        if let favURL = URL(string: "https://www.google.com/s2/favicons?domain=\(domain)&sz=64"),
           let (favData, _) = try? await URLSession.shared.data(from: favURL),
           let img = NSImage(data: favData) {
            meta.faviconImage = img
        }

        // Plateformes vidéo : oEmbed (plus fiable et léger que HTML)
        if let oEmbed = await fetchOEmbed(url: url) {
            meta.title = oEmbed.title
            if let thumbStr = oEmbed.thumbnailURL,
               let thumbURL = URL(string: thumbStr),
               let (imgData, _) = try? await URLSession.shared.data(from: thumbURL),
               let img = NSImage(data: imgData) {
                meta.ogImage = img
            }
            return meta
        }

        // HTML fetch standard avec limite de taille
        var request = URLRequest(url: url)
        request.timeoutInterval = 5
        request.setValue("Mozilla/5.0 (Macintosh; Intel Mac OS X 10_15_7) AppleWebKit/537.36", forHTTPHeaderField: "User-Agent")
        request.setValue("text/html", forHTTPHeaderField: "Accept")

        guard let (data, _) = try? await URLSession.shared.data(for: request) else { return meta }
        let truncated = data.count > maxHTMLBytes ? data.prefix(maxHTMLBytes) : data
        guard let html = String(data: truncated, encoding: .utf8) ?? String(data: truncated, encoding: .isoLatin1)
        else { return meta }

        meta.title = ogTag(html, "og:title")
            ?? ogTag(html, "twitter:title")
            ?? htmlTitle(html)

        if let imgStr = ogTag(html, "og:image"),
           let imgURL = URL(string: imgStr.hasPrefix("http") ? imgStr : baseURL(url) + imgStr),
           let (imgData, _) = try? await URLSession.shared.data(from: imgURL),
           let img = NSImage(data: imgData) {
            meta.ogImage = img
        }

        return meta
    }

    // MARK: - oEmbed (YouTube, Vimeo, Twitter/X, etc.)

    private struct OEmbedResponse: Decodable {
        let title: String?
        let thumbnailURL: String?
        enum CodingKeys: String, CodingKey {
            case title
            case thumbnailURL = "thumbnail_url"
        }
    }

    private static func oEmbedEndpoint(for url: URL) -> URL? {
        let s = url.absoluteString
        if url.host?.contains("youtube.com") == true || url.host?.contains("youtu.be") == true {
            let encoded = s.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? s
            return URL(string: "https://www.youtube.com/oembed?url=\(encoded)&format=json")
        }
        if url.host?.contains("vimeo.com") == true {
            let encoded = s.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? s
            return URL(string: "https://vimeo.com/api/oembed.json?url=\(encoded)")
        }
        return nil
    }

    private static func fetchOEmbed(url: URL) async -> OEmbedResponse? {
        guard let endpoint = oEmbedEndpoint(for: url) else { return nil }
        var req = URLRequest(url: endpoint)
        req.timeoutInterval = 5
        guard let (data, _) = try? await URLSession.shared.data(for: req) else { return nil }
        return try? JSONDecoder().decode(OEmbedResponse.self, from: data)
    }

    // MARK: - HTML parsing

    private static func ogTag(_ html: String, _ property: String) -> String? {
        let patterns = [
            #"<meta[^>]+property=["']\#(property)["'][^>]+content=["']([^"'<>]+)["']"#,
            #"<meta[^>]+content=["']([^"'<>]+)["'][^>]+property=["']\#(property)["']"#,
            #"<meta[^>]+name=["']\#(property)["'][^>]+content=["']([^"'<>]+)["']"#,
        ]
        for pattern in patterns {
            if let value = firstCapture(html, pattern: pattern) { return htmlDecode(value) }
        }
        return nil
    }

    private static func htmlTitle(_ html: String) -> String? {
        guard let value = firstCapture(html, pattern: #"<title[^>]*>([^<]{1,200})</title>"#) else { return nil }
        return htmlDecode(value).trimmingCharacters(in: .whitespacesAndNewlines)
    }

    private static func firstCapture(_ string: String, pattern: String) -> String? {
        guard let regex = try? NSRegularExpression(pattern: pattern, options: [.caseInsensitive, .dotMatchesLineSeparators]),
              let match = regex.firstMatch(in: string, range: NSRange(string.startIndex..., in: string)),
              match.numberOfRanges > 1,
              let range = Range(match.range(at: 1), in: string) else { return nil }
        return String(string[range])
    }

    private static func htmlDecode(_ string: String) -> String {
        string
            .replacingOccurrences(of: "&amp;",  with: "&")
            .replacingOccurrences(of: "&lt;",   with: "<")
            .replacingOccurrences(of: "&gt;",   with: ">")
            .replacingOccurrences(of: "&quot;", with: "\"")
            .replacingOccurrences(of: "&#39;",  with: "'")
            .replacingOccurrences(of: "&nbsp;", with: " ")
    }

    private static func baseURL(_ url: URL) -> String {
        "\(url.scheme ?? "https")://\(url.host ?? "")"
    }
}
