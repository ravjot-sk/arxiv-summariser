import Foundation

#if canImport(MLXLLM)
import MLX
import MLXLLM
import MLXLMCommon
#endif

enum GemmaError: Error { case unavailable, notReady }

/// On-device Gemma text generation via MLX. Exposes the same
/// `generate(system:prompt:asJSON:)` shape as `GeminiClient` so `SummaryService`
/// can route to it interchangeably. An `actor` so the heavy GPU work is
/// serialized and stays off the main thread.
actor GemmaEngine {
    static let shared = GemmaEngine()

    /// Ready only when the model has been downloaded + loaded.
    var isReady: Bool {
        get async { await GemmaModelManager.shared.isReady }
    }

    func generate(system: String, prompt: String, asJSON: Bool) async throws -> String {
        #if canImport(MLXLLM)
        guard let container = await GemmaModelManager.shared.loadedContainer() else {
            throw GemmaError.notReady
        }
        // Keep MLX's GPU cache modest so we don't trip iOS memory limits.
        MLX.GPU.set(cacheLimit: 64 * 1024 * 1024)

        // High-level MLXLMCommon API: a fresh ChatSession per call (independent
        // summaries, no carried-over chat context), system prompt as instructions.
        let session = ChatSession(
            container,
            instructions: system,
            generateParameters: GenerateParameters(maxTokens: 512, temperature: 0.3)
        )
        let text = try await session.respond(to: prompt)
        return text.trimmingCharacters(in: .whitespacesAndNewlines)
        #else
        throw GemmaError.unavailable
        #endif
    }
}
