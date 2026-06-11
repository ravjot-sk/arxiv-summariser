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

        let messages: [[String: String]] = [
            ["role": "system", "content": system],
            ["role": "user", "content": prompt],
        ]

        // ⚠️ Verify this call against the installed mlx-swift-examples version —
        // the generate/UserInput API has shifted across releases. The shape below
        // matches the MLXLMCommon `perform { context in … generate … }` pattern.
        let result = try await container.perform { context in
            let input = try await context.processor.prepare(input: UserInput(messages: messages))
            return try MLXLMCommon.generate(
                input: input,
                parameters: GenerateParameters(temperature: 0.3),
                context: context
            ) { _ in .more }
        }
        return result.output.trimmingCharacters(in: .whitespacesAndNewlines)
        #else
        throw GemmaError.unavailable
        #endif
    }
}
