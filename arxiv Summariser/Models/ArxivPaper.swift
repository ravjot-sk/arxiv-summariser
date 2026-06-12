import Foundation

struct ArxivPaper: Identifiable, Codable, Hashable {
    let id: String
    let title: String
    let summary: String
    let authors: [String]
    let published: Date
    let updated: Date
    let primaryCategory: String
    let categories: [String]
    let absURL: URL
    let pdfURL: URL?

    var authorList: String {
        authors.joined(separator: ", ")
    }

    /// arXiv's HTML rendering of the paper. Not every paper has one (conversion
    /// can fail or be missing) — check with `ArxivHTMLCheck` before showing UI.
    var htmlURL: URL? {
        var s = absURL.absoluteString.replacingOccurrences(of: "/abs/", with: "/html/")
        if s.hasPrefix("http://") {                       // the API returns http URLs
            s = "https://" + s.dropFirst("http://".count)
        }
        guard s.contains("/html/") else { return nil }
        return URL(string: s)
    }

    var cleanedSummary: String {
        summary
            .replacingOccurrences(of: "\n", with: " ")
            .replacingOccurrences(of: "  ", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    var cleanedTitle: String {
        title
            .replacingOccurrences(of: "\n", with: " ")
            .trimmingCharacters(in: .whitespacesAndNewlines)
    }

    /// Up to two short, readable keyword labels (primary category first), used for tags and filtering.
    var displayKeywords: [String] {
        var ordered = [primaryCategory]
        ordered.append(contentsOf: categories)
        var seen = Set<String>()
        var result: [String] = []
        for code in ordered where !code.isEmpty {
            let label = ArxivCategory.keyword(for: code)
            if seen.insert(label).inserted {
                result.append(label)
                if result.count == 2 { break }
            }
        }
        return result
    }
}
