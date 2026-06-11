import Foundation

/// On-device Gemma (via MLX Swift) configuration.
///
/// The model is **downloaded on first use** from Hugging Face into the app
/// container (a usable 4-bit Gemma is too large to embed in the app binary).
enum GemmaConfig {
    /// Hugging Face repo id for an MLX 4-bit Gemma instruct model.
    /// Prefer a NON-gated `mlx-community` re-quant so no HF token / license click
    /// is needed. ⚠️ Confirm this exact id exists on Hugging Face before relying
    /// on it (browse https://huggingface.co/mlx-community?search=gemma).
    static let modelID = "mlx-community/gemma-3-1b-it-4bit"

    /// Human-facing label and rough on-disk size for the download UI.
    static let displayName = "Gemma 3 1B (4-bit)"
    static let approxDownloadSize = "~0.7 GB"
}
