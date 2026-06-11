import Foundation

#if canImport(FoundationModels)
import FoundationModels
#endif

struct SummaryResult {
    let text: String
    let generatedByAI: Bool
}

enum AIAvailability {
    case available
    case unavailable(String)
}

/// Which engine produced summaries.
enum SummaryProvider {
    case gemma
    case gemini
    case onDevice

    var displayName: String {
        switch self {
        case .gemma: return "On-device Gemma"
        case .gemini: return "Gemini"
        case .onDevice: return "Apple Intelligence"
        }
    }
}

enum AIGenerationStatus {
    case checking
    case working(SummaryProvider)
    /// The active provider is configured but a test generation failed.
    case failing(String)
    case unavailable(String)
}

/// Facade over the active summarization backend. Routing follows the user's
/// `SummaryPreferences.engine`: on-device Gemma (MLX) → Gemini (cloud) → Apple
/// FoundationModels → plain trimmed abstracts, with graceful fallback.
struct SummaryService {
    static let shared = SummaryService()

    private let gemini = GeminiClient.shared

    private static let paperSystemPrompt = """
    You summarize research papers for a curious non-specialist in one or two \
    plain-language sentences each. Be accurate and never invent details that are \
    not in the abstract.
    """

    // MARK: - LLM routing

    /// Ordered hosted/on-device LLM backends to try for the current preference.
    /// (Apple FoundationModels and the abstract fallback are handled separately.)
    private func llmChain() -> [SummaryProvider] {
        switch SummaryPreferences.engine {
        case .gemma:     return [.gemma, .gemini]   // prefer Gemma, Gemini as a net
        case .gemini:    return [.gemini]
        case .apple:     return []                  // skip → Apple path below
        case .automatic: return [.gemma, .gemini]
        }
    }

    /// Generate text from the first available backend in the chain, else nil.
    private func tryLLM(system: String, prompt: String, asJSON: Bool) async -> String? {
        for provider in llmChain() {
            switch provider {
            case .gemma:
                if await GemmaEngine.shared.isReady,
                   let text = try? await GemmaEngine.shared.generate(system: system, prompt: prompt, asJSON: asJSON) {
                    return text
                }
            case .gemini:
                if GeminiConfig.isConfigured,
                   let text = try? await gemini.generate(system: system, prompt: prompt, asJSON: asJSON) {
                    return text
                }
            case .onDevice:
                break
            }
        }
        return nil
    }

    // MARK: - On-device (Apple) availability

    var availability: AIAvailability {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            switch SystemLanguageModel.default.availability {
            case .available:
                return .available
            case .unavailable(let reason):
                return .unavailable(Self.describe(reason))
            }
        }
        #endif
        return .unavailable("This device doesn't support on-device summaries.")
    }

    var isAIAvailable: Bool {
        if case .available = availability { return true }
        return false
    }

    // MARK: - Status probe (Settings)

    func probeGeneration() async -> AIGenerationStatus {
        let pref = SummaryPreferences.engine

        // Gemma (on-device) — when selected or automatic.
        if pref == .gemma || pref == .automatic {
            if await GemmaEngine.shared.isReady,
               (try? await GemmaEngine.shared.generate(system: "Reply concisely.", prompt: "Reply OK", asJSON: false)) != nil {
                return .working(.gemma)
            }
            if pref == .gemma {
                switch await GemmaModelManager.shared.state {
                case .downloading: return .failing("The Gemma model is still downloading…")
                case .failed(let message): return .failing(message)
                case .notDownloaded, .unavailable:
                    return .failing("Download the Gemma model in Settings (or run on a device) to use on-device summaries.")
                case .ready: break
                }
            }
        }

        // Gemini (cloud).
        if pref == .gemini || pref == .automatic || pref == .gemma {
            if GeminiConfig.isConfigured {
                if (try? await gemini.generate(system: "Reply concisely.", prompt: "Reply with the single word: OK", asJSON: false)) != nil {
                    return .working(.gemini)
                }
                if pref == .gemini {
                    return .failing("Couldn't reach Gemini — check the API key and your connection.")
                }
            }
        }

        // Apple FoundationModels.
        if case .unavailable(let reason) = availability {
            return .unavailable(reason)
        }
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *) {
            do {
                let session = LanguageModelSession(instructions: "Reply concisely.")
                _ = try await session.respond(to: "Reply with the single word: OK")
                return .working(.onDevice)
            } catch {
                return .failing("The on-device model is reported as available but couldn't run a test summary here, so plain abstracts are shown instead.")
            }
        }
        #endif
        return .unavailable("On-device summaries aren't supported on this device.")
    }

    // MARK: - Per-paper summaries (batched)

    /// Summaries for a set of papers, keyed by `paper.id`. One batched LLM request
    /// when a hosted/on-device LLM is active; otherwise per-paper Apple/abstract.
    func summaries(for papers: [ArxivPaper]) async -> [String: SummaryResult] {
        guard !papers.isEmpty else { return [:] }

        if var batched = await llmBatchSummaries(papers) {
            for paper in papers where batched[paper.id] == nil {
                batched[paper.id] = await onDeviceSummarizePaper(paper)
            }
            return batched
        }

        var result: [String: SummaryResult] = [:]
        for paper in papers {
            result[paper.id] = await onDeviceSummarizePaper(paper)
        }
        return result
    }

    /// Summarize a single paper. Active LLM → Apple → trimmed abstract.
    func summarizePaper(_ paper: ArxivPaper) async -> SummaryResult {
        let prompt = "Summarize this paper in 1–2 plain-language sentences.\n\nTitle: \(paper.cleanedTitle)\nAbstract: \(paper.cleanedSummary)"
        if let text = await tryLLM(system: Self.paperSystemPrompt, prompt: prompt, asJSON: false) {
            return SummaryResult(text: text, generatedByAI: true)
        }
        return await onDeviceSummarizePaper(paper)
    }

    private func llmBatchSummaries(_ papers: [ArxivPaper]) async -> [String: SummaryResult]? {
        let list = papers.enumerated().map { index, paper in
            "[\(index)] Title: \(paper.cleanedTitle)\nAbstract: \(paper.cleanedSummary)"
        }.joined(separator: "\n\n")
        let prompt = """
        Summarize each paper below in 1–2 plain-language sentences for a curious \
        non-specialist. Respond with ONLY a JSON array; each element must be \
        {"index": <the bracketed number>, "summary": "<your summary>"}, one per paper.

        \(list)
        """
        guard let json = await tryLLM(system: Self.paperSystemPrompt, prompt: prompt, asJSON: true),
              let items = Self.decodeBatch(json) else {
            return nil
        }

        var result: [String: SummaryResult] = [:]
        for item in items where item.index >= 0 && item.index < papers.count {
            let text = item.summary.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !text.isEmpty else { continue }
            result[papers[item.index].id] = SummaryResult(text: text, generatedByAI: true)
        }
        return result.isEmpty ? nil : result
    }

    // MARK: - Overview (reduce)

    func combineSummaries(_ items: [(title: String, summary: String)], scope: String) async -> SummaryResult {
        guard !items.isEmpty else {
            return SummaryResult(text: "No papers to summarize for \(scope) right now.", generatedByAI: false)
        }

        let system = """
        You merge short per-paper summaries into one concise, plain-language \
        overview. Group related work, surface the key themes, and remove \
        redundancy. Never invent findings.
        """
        let body = items.enumerated()
            .map { index, item in "\(index + 1). \(item.title): \(item.summary)" }
            .joined(separator: "\n")
        let ask = "Here are short summaries of today's papers on \(scope). Write 3–5 short, plain-language bullet points capturing the key themes and most notable findings. Respond with only the bullets, one per line starting with \"- \", with no introductory or closing sentence:\n\n\(body)"

        if let text = await tryLLM(system: system, prompt: ask, asJSON: false) {
            return SummaryResult(text: text, generatedByAI: true)
        }

        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), isAIAvailable {
            do {
                let session = LanguageModelSession(instructions: system)
                let response = try await session.respond(to: ask)
                return SummaryResult(text: response.content, generatedByAI: true)
            } catch {
                // fall through to a plain joined list
            }
        }
        #endif
        let text = items.map { "• \($0.title)\n\($0.summary)" }.joined(separator: "\n\n")
        return SummaryResult(text: text, generatedByAI: false)
    }

    private struct BatchItem: Decodable {
        let index: Int
        let summary: String
    }

    private static func decodeBatch(_ json: String) -> [BatchItem]? {
        // Strip ```json fences if the model added them despite the JSON mime type.
        var text = json.trimmingCharacters(in: .whitespacesAndNewlines)
        if text.hasPrefix("```") {
            text = text
                .replacingOccurrences(of: "```json", with: "")
                .replacingOccurrences(of: "```", with: "")
                .trimmingCharacters(in: .whitespacesAndNewlines)
        }
        guard let data = text.data(using: .utf8) else { return nil }
        return try? JSONDecoder().decode([BatchItem].self, from: data)
    }

    // MARK: - On-device (Apple) / abstract fallback

    private func onDeviceSummarizePaper(_ paper: ArxivPaper) async -> SummaryResult {
        #if canImport(FoundationModels)
        if #available(iOS 26.0, *), isAIAvailable {
            do {
                let session = LanguageModelSession(instructions: Self.paperSystemPrompt)
                let ask = "Summarize this paper in 1–2 sentences.\n\nTitle: \(paper.cleanedTitle)\nAbstract: \(paper.cleanedSummary)"
                let response = try await session.respond(to: ask)
                return SummaryResult(text: response.content, generatedByAI: true)
            } catch {
                // fall through to abstract-based fallback
            }
        }
        #endif
        let abstract = paper.cleanedSummary
        let trimmed = abstract.count > 240 ? String(abstract.prefix(240)) + "…" : abstract
        return SummaryResult(text: trimmed, generatedByAI: false)
    }

    #if canImport(FoundationModels)
    private static func describe(_ reason: SystemLanguageModel.Availability.UnavailableReason) -> String {
        switch reason {
        case .deviceNotEligible:
            return "This device isn't eligible for Apple Intelligence."
        case .appleIntelligenceNotEnabled:
            return "Turn on Apple Intelligence in Settings to get AI summaries."
        case .modelNotReady:
            return "The on-device model is still downloading. Try again shortly."
        @unknown default:
            return "On-device summaries are unavailable right now."
        }
    }
    #endif
}

extension Array {
    func chunked(into size: Int) -> [[Element]] {
        guard size > 0 else { return [self] }
        return stride(from: 0, to: count, by: size).map {
            Array(self[$0..<Swift.min($0 + size, count)])
        }
    }
}
