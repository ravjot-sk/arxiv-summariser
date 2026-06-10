import Foundation

enum ArxivAPIError: Error {
    case badResponse
    case parseFailed
}

/// Serializes arXiv requests and guarantees a minimum spacing between them
/// across every caller (foreground refresh, background task, …), honoring
/// arXiv's "≤ 1 request / 3 seconds, single connection" guidance.
actor ArxivRequestGate {
    static let shared = ArxivRequestGate()

    private let minInterval: TimeInterval = 3.0
    private var nextSlot: Date = .distantPast

    /// Reserve the next allowed request time; each reservation is at least
    /// `minInterval` after the previous one. Non-reentrant (no awaits), so
    /// concurrent callers can't collide.
    func reserveSlot() -> Date {
        let slot = max(Date(), nextSlot)
        nextSlot = slot.addingTimeInterval(minInterval)
        return slot
    }
}

struct ArxivAPIClient {
    static let shared = ArxivAPIClient()

    private let session: URLSession
    private let userAgent = "arxivSummariser/1.0 (https://arxiv.org; mailto:12.rs.94@gmail.com)"

    init(session: URLSession = .shared) {
        self.session = session
    }

    /// Fetch the most recent papers for a category, newest first.
    ///
    /// Every request passes through `ArxivRequestGate` (global ≥3s spacing,
    /// single connection), and a 503/429 response is retried a few times —
    /// honoring `Retry-After` — before giving up.
    func recentPapers(category: String, maxResults: Int = 10) async throws -> [ArxivPaper] {
        var components = URLComponents(string: "https://export.arxiv.org/api/query")!
        components.queryItems = [
            URLQueryItem(name: "search_query", value: "cat:\(category)"),
            URLQueryItem(name: "sortBy", value: "submittedDate"),
            URLQueryItem(name: "sortOrder", value: "descending"),
            URLQueryItem(name: "max_results", value: String(maxResults)),
        ]

        var request = URLRequest(url: components.url!)
        request.setValue(userAgent, forHTTPHeaderField: "User-Agent")
        request.timeoutInterval = 30

        let maxAttempts = 3
        for attempt in 1...maxAttempts {
            // Wait for this request's reserved slot (global ≥3s spacing).
            let slot = await ArxivRequestGate.shared.reserveSlot()
            let wait = slot.timeIntervalSinceNow
            if wait > 0 { try await Task.sleep(for: .seconds(wait)) }

            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else {
                    throw ArxivAPIError.badResponse
                }

                if (200..<300).contains(http.statusCode) {
                    return try ArxivFeedParser().parse(data: data)
                }

                // arXiv returns 503 when overloaded / rate-limited; 429 = too many.
                let isRetryable = http.statusCode == 503 || http.statusCode == 429
                guard isRetryable, attempt < maxAttempts else {
                    throw ArxivAPIError.badResponse
                }
                try await Task.sleep(for: .seconds(Self.retryDelay(from: http, attempt: attempt)))
            } catch let error as URLError where Self.isTransient(error) && attempt < maxAttempts {
                // Transient network error (e.g. a timeout) — back off and retry.
                try await Task.sleep(for: .seconds(Double(attempt) * 5))
            }
        }

        throw ArxivAPIError.badResponse
    }

    /// Network errors worth retrying — transient connectivity or server slowness,
    /// as opposed to permanent failures (bad URL, cancellation, …).
    private static func isTransient(_ error: URLError) -> Bool {
        switch error.code {
        case .timedOut, .networkConnectionLost, .cannotConnectToHost,
             .cannotFindHost, .dnsLookupFailed, .resourceUnavailable,
             .notConnectedToInternet:
            return true
        default:
            return false
        }
    }

    /// Seconds to wait before retrying: the `Retry-After` header if present
    /// (clamped to a sane range), otherwise a growing backoff.
    private static func retryDelay(from response: HTTPURLResponse, attempt: Int) -> Double {
        if let header = response.value(forHTTPHeaderField: "Retry-After"),
           let seconds = Double(header.trimmingCharacters(in: .whitespaces)) {
            return min(max(seconds, 1), 60)
        }
        return Double(attempt) * 5   // 5s, 10s, …
    }
}

/// Minimal Atom-feed parser for the arXiv API.
private final class ArxivFeedParser: NSObject, XMLParserDelegate {
    private var papers: [ArxivPaper] = []

    // Per-entry accumulators
    private var inEntry = false
    private var currentText = ""
    private var id = ""
    private var title = ""
    private var summary = ""
    private var authors: [String] = []
    private var publishedStr = ""
    private var updatedStr = ""
    private var primaryCategory = ""
    private var categories: [String] = []
    private var absURL: URL?
    private var pdfURL: URL?
    private var inAuthor = false

    private static let iso: ISO8601DateFormatter = {
        let f = ISO8601DateFormatter()
        f.formatOptions = [.withInternetDateTime]
        return f
    }()

    func parse(data: Data) throws -> [ArxivPaper] {
        let parser = XMLParser(data: data)
        parser.delegate = self
        guard parser.parse() else { throw ArxivAPIError.parseFailed }
        return papers
    }

    func parser(_ parser: XMLParser, didStartElement elementName: String, namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        currentText = ""
        switch elementName {
        case "entry":
            inEntry = true
            id = ""; title = ""; summary = ""; authors = []
            publishedStr = ""; updatedStr = ""; primaryCategory = ""
            categories = []; absURL = nil; pdfURL = nil
        case "author":
            inAuthor = true
        case "link" where inEntry:
            let rel = attributeDict["rel"]
            let type = attributeDict["type"]
            if let href = attributeDict["href"], let url = URL(string: href) {
                if rel == "alternate", type == "text/html" {
                    absURL = url
                } else if type == "application/pdf" {
                    pdfURL = url
                }
            }
        case "category" where inEntry:
            if let term = attributeDict["term"] { categories.append(term) }
        case "arxiv:primary_category", "primary_category":
            if let term = attributeDict["term"] { primaryCategory = term }
        default:
            break
        }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) {
        currentText += string
    }

    func parser(_ parser: XMLParser, didEndElement elementName: String, namespaceURI: String?, qualifiedName qName: String?) {
        let text = currentText.trimmingCharacters(in: .whitespacesAndNewlines)
        switch elementName {
        case "name" where inAuthor:
            if !text.isEmpty { authors.append(text) }
        case "author":
            inAuthor = false
        case "id" where inEntry:
            id = text
        case "title" where inEntry:
            title = text
        case "summary" where inEntry:
            summary = text
        case "published" where inEntry:
            publishedStr = text
        case "updated" where inEntry:
            updatedStr = text
        case "entry":
            finishEntry()
            inEntry = false
        default:
            break
        }
        currentText = ""
    }

    private func finishEntry() {
        guard !id.isEmpty else { return }
        let published = Self.iso.date(from: publishedStr) ?? .now
        let updated = Self.iso.date(from: updatedStr) ?? published
        let abs = absURL ?? URL(string: id) ?? URL(string: "https://arxiv.org")!
        let paper = ArxivPaper(
            id: id,
            title: title,
            summary: summary,
            authors: authors,
            published: published,
            updated: updated,
            primaryCategory: primaryCategory.isEmpty ? (categories.first ?? "") : primaryCategory,
            categories: categories,
            absURL: abs,
            pdfURL: pdfURL
        )
        papers.append(paper)
    }
}
