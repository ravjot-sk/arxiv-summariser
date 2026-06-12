import Foundation

/// Checks whether arXiv actually serves an HTML rendering for a paper
/// (arxiv.org answers 200 when it exists, 404 when the conversion is missing).
/// Results are cached in memory so revisiting a paper doesn't re-request.
actor ArxivHTMLCheck {
    static let shared = ArxivHTMLCheck()

    private var cache: [URL: Bool] = [:]

    func isAvailable(_ url: URL) async -> Bool {
        if let cached = cache[url] { return cached }

        var request = URLRequest(url: url, timeoutInterval: 10)
        request.httpMethod = "HEAD"

        let available: Bool
        do {
            let (_, response) = try await URLSession.shared.data(for: request)
            if let http = response as? HTTPURLResponse {
                // Guard against a redirect away from /html/ (e.g. back to the abs page).
                let stillHTML = (http.url ?? url).path.contains("/html/")
                available = http.statusCode == 200 && stillHTML
            } else {
                available = false
            }
        } catch {
            available = false                 // offline etc. — just hide the button
        }

        cache[url] = available
        return available
    }
}
