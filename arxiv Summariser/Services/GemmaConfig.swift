import Foundation

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
}

/// The models the user can download and switch between. All are non-gated
/// `mlx-community` 4-bit re-quants small enough for a phone. Add more ids here
/// (verify they exist at huggingface.co/mlx-community before shipping).
enum GemmaCatalog {
    static let models: [GemmaModelInfo] = [
        GemmaModelInfo(id: "mlx-community/gemma-3-1b-it-4bit", name: "Gemma 3 1B", approxSize: "≈ 0.7 GB"),
        GemmaModelInfo(id: "mlx-community/gemma-1.1-2b-it-4bit", name: "Gemma 1.1 2B", approxSize: "≈ 1.4 GB"),
    ]

    static var `default`: GemmaModelInfo { models[0] }

    static func info(for id: String) -> GemmaModelInfo? {
        models.first { $0.id == id }
    }
}
