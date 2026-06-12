import Foundation

/// Which on-device backend loads and runs a given model.
///
/// Older Gemma generations load through MLX's text-only `LLMModelFactory`
/// (`mlx-swift-examples`). Gemma 4's architecture isn't supported there, so its
/// models go through the `Gemma4Swift` package instead. See `GemmaModelManager`.
enum GemmaRuntime: Hashable {
    case mlxLLM
    case gemma4Swift
}

/// A downloadable on-device model (MLX 4-bit Gemma instruct).
///
/// Named `GemmaModelInfo` (not `GemmaModel`) to avoid clashing with the model
/// type of the same name inside the `MLXLLM` module.
struct GemmaModelInfo: Identifiable, Hashable {
    /// Hugging Face repo id, e.g. "mlx-community/gemma-3-1b-it-4bit".
    let id: String
    let name: String
    /// Rough download size, for the UI.
    let approxSize: String
    /// Which on-device backend loads this model.
    var runtime: GemmaRuntime = .mlxLLM
}

/// The models the user can download and switch between. All are non-gated
/// `mlx-community` 4-bit re-quants small enough for a phone. Add more ids here
/// (verify they exist at huggingface.co/mlx-community before shipping).
enum GemmaCatalog {
    static let models: [GemmaModelInfo] = [
        GemmaModelInfo(id: "mlx-community/gemma-3-1b-it-4bit", name: "Gemma 3 1B", approxSize: "≈ 0.7 GB"),
        GemmaModelInfo(id: "mlx-community/gemma-1.1-2b-it-4bit", name: "Gemma 1.1 2B", approxSize: "≈ 1.4 GB"),
        // Gemma 4 isn't supported by mlx-swift-examples; it loads via the
        // Gemma4Swift package (text-only path). The repo id must match a case of
        // `Gemma4Pipeline.Model` (its raw value is the Hugging Face id).
        GemmaModelInfo(id: "mlx-community/gemma-4-e2b-it-4bit", name: "Gemma 4 E2B", approxSize: "≈ 3.6 GB", runtime: .gemma4Swift),
    ]

    static var `default`: GemmaModelInfo { models[0] }

    static func info(for id: String) -> GemmaModelInfo? {
        models.first { $0.id == id }
    }
}
