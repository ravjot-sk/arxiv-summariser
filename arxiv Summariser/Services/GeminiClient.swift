import Foundation

enum GeminiError: Error {
    case notConfigured
    case badResponse
    case blocked
    case empty
}

/// Spaces out Gemini requests across all callers so we stay within rate limits,
/// mirroring `ArxivRequestGate`.
actor GeminiRequestGate {
    static let shared = GeminiRequestGate()

    private let minInterval: TimeInterval = 1.0
    private var nextSlot: Date = .distantPast

    func reserveSlot() -> Date {
        let slot = max(Date(), nextSlot)
        nextSlot = slot.addingTimeInterval(minInterval)
        return slot
    }
}

/// Thin client over the Gemini `generateContent` REST endpoint. Throws on any
/// failure so `SummaryService` can fall back to the on-device model.
struct GeminiClient {
    static let shared = GeminiClient()

    private let session: URLSession
    init(session: URLSession = .shared) { self.session = session }

    /// Generate text for `prompt` under `system` guidance. `asJSON` requests a
    /// raw-JSON response (used for batched structured output).
    func generate(system: String, prompt: String, asJSON: Bool) async throws -> String {
        guard GeminiConfig.isConfigured else { throw GeminiError.notConfigured }
        guard let url = URL(string: "https://generativelanguage.googleapis.com/v1beta/models/\(GeminiConfig.model):generateContent") else {
            throw GeminiError.badResponse
        }

        let payload = RequestBody(
            system_instruction: .init(parts: [.init(text: system)]),
            contents: [.init(role: "user", parts: [.init(text: prompt)])],
            generationConfig: .init(
                temperature: 0.3,
                maxOutputTokens: 2048,
                responseMimeType: asJSON ? "application/json" : "text/plain"
            )
        )

        var request = URLRequest(url: url)
        request.httpMethod = "POST"
        request.timeoutInterval = 30
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        request.setValue(GeminiConfig.apiKey, forHTTPHeaderField: "x-goog-api-key")
        request.httpBody = try JSONEncoder().encode(payload)

        let maxAttempts = 3
        for attempt in 1...maxAttempts {
            // Global ≥1s spacing between Gemini requests.
            let slot = await GeminiRequestGate.shared.reserveSlot()
            let wait = slot.timeIntervalSinceNow
            if wait > 0 { try await Task.sleep(for: .seconds(wait)) }

            do {
                let (data, response) = try await session.data(for: request)
                guard let http = response as? HTTPURLResponse else { throw GeminiError.badResponse }

                if (200..<300).contains(http.statusCode) {
                    return try Self.extractText(from: data)
                }
                // 429 = rate limited, 5xx = transient server error.
                let retryable = http.statusCode == 429 || (500...599).contains(http.statusCode)
                guard retryable, attempt < maxAttempts else { throw GeminiError.badResponse }
                try await Task.sleep(for: .seconds(Self.retryDelay(http, attempt)))
            } catch let error as URLError where Self.isTransient(error) && attempt < maxAttempts {
                try await Task.sleep(for: .seconds(Double(attempt) * 3))
            }
        }
        throw GeminiError.badResponse
    }

    // MARK: - Response handling

    private static func extractText(from data: Data) throws -> String {
        let decoded = try JSONDecoder().decode(GenerateContentResponse.self, from: data)
        guard let candidate = decoded.candidates?.first else { throw GeminiError.empty }
        if let reason = candidate.finishReason,
           ["SAFETY", "BLOCKLIST", "PROHIBITED_CONTENT", "RECITATION"].contains(reason) {
            throw GeminiError.blocked
        }
        let text = (candidate.content?.parts ?? [])
            .compactMap(\.text)
            .joined()
            .trimmingCharacters(in: .whitespacesAndNewlines)
        guard !text.isEmpty else { throw GeminiError.empty }
        return text
    }

    private static func retryDelay(_ response: HTTPURLResponse, _ attempt: Int) -> Double {
        if let header = response.value(forHTTPHeaderField: "Retry-After"),
           let seconds = Double(header.trimmingCharacters(in: .whitespaces)) {
            return min(max(seconds, 1), 60)
        }
        return Double(attempt) * 3
    }

    private static func isTransient(_ error: URLError) -> Bool {
        switch error.code {
        case .timedOut, .networkConnectionLost, .cannotConnectToHost,
             .cannotFindHost, .dnsLookupFailed, .notConnectedToInternet:
            return true
        default:
            return false
        }
    }
}

// MARK: - Wire types

private struct RequestBody: Encodable {
    struct Part: Encodable { let text: String }
    struct Content: Encodable { var role: String? = nil; let parts: [Part] }
    struct SystemInstruction: Encodable { let parts: [Part] }
    struct GenerationConfig: Encodable {
        let temperature: Double
        let maxOutputTokens: Int
        let responseMimeType: String
    }
    let system_instruction: SystemInstruction
    let contents: [Content]
    let generationConfig: GenerationConfig
}

private struct GenerateContentResponse: Decodable {
    struct Candidate: Decodable {
        struct Content: Decodable {
            struct Part: Decodable { let text: String? }
            let parts: [Part]?
        }
        let content: Content?
        let finishReason: String?
    }
    let candidates: [Candidate]?
}
