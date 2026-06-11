import Foundation

/// Configuration for the hosted Google Gemini summarizer.
///
/// 🔑 The API key lives in `Secrets.swift` (gitignored, not in this file). To
/// switch summaries to Gemini, set `Secrets.geminiAPIKey`. Leave it empty to keep
/// using the on-device model.
enum GeminiConfig {

    /// Provided via the gitignored `Secrets.swift` so the key never enters source control.
    static let apiKey = Secrets.geminiAPIKey

    /// The Gemini model id. Confirm the exact string in AI Studio and adjust if
    /// needed (e.g. "gemini-flash-lite-latest").
    static let model = "gemini-3.1-flash-lite"

    /// True once a key has been provided — gates the Gemini code paths.
    static var isConfigured: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
