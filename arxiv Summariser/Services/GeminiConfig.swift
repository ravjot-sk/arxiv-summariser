import Foundation

/// Configuration for the hosted Google Gemini summarizer.
///
/// 🔑 To switch summaries from the slow on-device model to Gemini, paste your
/// API key into `apiKey` below. Get a key at https://aistudio.google.com/apikey.
/// Leave it empty to keep using the on-device model.
///
/// ⚠️ Don't commit your real key. This project isn't a git repo today; if you
/// initialize one, either keep this file untracked
/// (`git update-index --skip-worktree`) or move the key out of source.
enum GeminiConfig {

    // ┌─────────────────────────────────────────────────────────────────┐
    // │  PUT YOUR GEMINI API KEY HERE                                     │
    // └─────────────────────────────────────────────────────────────────┘
    static let apiKey = ""

    /// The Gemini model id. Confirm the exact string in AI Studio and adjust if
    /// needed (e.g. "gemini-flash-lite-latest").
    static let model = "gemini-3.1-flash-lite"

    /// True once a key has been provided — gates the Gemini code paths.
    static var isConfigured: Bool {
        !apiKey.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}
