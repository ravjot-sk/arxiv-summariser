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

/// Which engine produces summaries.
enum SummaryProvider {
    case gemini
    case onDevice

    var displayName: String {
        switch self {
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

/// Facade over the active summarization backend: Google Gemini when an API key
/// is configured, otherwise the on-device FoundationModels model, otherwise
/// plain trimmed abstracts.
struct SummaryService {
    static let shared = SummaryService()

    private let gemini = GeminiClient.shared

    /// Gemini is used whenever an API key has been provided in `GeminiConfig`.
    private var useGemini: Bool { GeminiConfig.isConfigured }

    private static let paperSystemPrompt = """
    You summarize research papers for a curious non-specialist in one or two \
    plain-language sentences each. Be accurate and never invent details that are \
    not in the abstract.
    """

    // MARK: - On-device availability

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

    /// Confirms the active provider can actually run a generation here.
    func probeGeneration() async -> AIGenerationStatus {
        if useGemini {
            do {
                _ = try await gemini.generate(system: "Reply concisely.", prompt: "Reply with the single word: OK", asJSON: false)
                return .working(.gemini)
            } catch {
                return .failing("Couldn't reach Gemini — check the API key and your connection. Falling back to the on-device model or plain abstracts.")
            }
        }

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

    /// Summaries for a set of papers, keyed by `paper.id`. Uses one batched
    /// Gemini request when configured; otherwise summarizes each paper with the
    /// on-device model (or a trimmed abstract).
    func summaries(for papers: [ArxivPaper]) async -> [String: SummaryResult] {
        guard !papers.isEmpty else { return [:] }

        if useGemini, var batched = await geminiBatchSummaries(papers) {
            // Fill any papers the batch missed with the on-device/abstract path.
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

    /// Summarize a single paper. Gemini → on-device → trimmed abstract.
    func summarizePaper(_ paper: ArxivPaper) async -> SummaryResult {
        if useGemini {
            let prompt = "Summarize this paper in 1–2 plain-language sentences.\n\nTitle: \(paper.cleanedTitle)\nAbstract: \(paper.cleanedSummary)"
            if let text = try? await gemini.generate(system: Self.paperSystemPrompt, prompt: prompt, asJSON: false) {
                return SummaryResult(text: text, generatedByAI: true)
            }
        }
        return await onDeviceSummarizePaper(paper)
    }

    // MARK: - Overview (reduce)

    /// Build an overview by reducing over already-summarized papers. Gemini →
    /// on-device → plain joined list.
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

        if useGemini, let text = try? await gemini.generate(system: system, prompt: ask, asJSON: false) {
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

    // MARK: - Gemini batch helper

    private func geminiBatchSummaries(_ papers: [ArxivPaper]) async -> [String: SummaryResult]? {
        let list = papers.enumerated().map { index, paper in
            "[\(index)] Title: \(paper.cleanedTitle)\nAbstract: \(paper.cleanedSummary)"
        }.joined(separator: "\n\n")
        let prompt = """
        Summarize each paper below in 1–2 plain-language sentences for a curious \
        non-specialist. Respond with ONLY a JSON array; each element must be \
        {"index": <the bracketed number>, "summary": "<your summary>"}, one per paper.

        \(list)
        """
        guard let json = try? await gemini.generate(system: Self.paperSystemPrompt, prompt: prompt, asJSON: true),
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

    // MARK: - On-device / abstract fallback

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
