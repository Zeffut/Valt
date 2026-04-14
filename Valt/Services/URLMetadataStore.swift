// Valt/Services/URLMetadataStore.swift
import AppKit
import Observation

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
            self.persistCache()
        }
    }

    // MARK: - Persistance

    private func loadPersistedCache() {
        guard let dict = UserDefaults.standard.dictionary(forKey: Self.udKey) as? [String: [String: String]] else { return }
        for (urlString, entry) in dict {
            guard let domain = entry["domain"] else { continue }
            cache[urlString] = Metadata(title: entry["title"], domain: domain)
        }
    }

    private func persistCache() {
        var dict: [String: [String: String]] = [:]
        for (urlString, meta) in cache {
            var entry: [String: String] = ["domain": meta.domain]
            if let title = meta.title { entry["title"] = title }
            dict[urlString] = entry
        }
        UserDefaults.standard.set(dict, forKey: Self.udKey)
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
        // YouTube
        if url.host?.contains("youtube.com") == true || url.host?.contains("youtu.be") == true {
            let encoded = s.addingPercentEncoding(withAllowedCharacters: .urlQueryAllowed) ?? s
            return URL(string: "https://www.youtube.com/oembed?url=\(encoded)&format=json")
        }
        // Vimeo
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
