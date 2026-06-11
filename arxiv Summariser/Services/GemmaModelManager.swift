import Foundation
import Combine

#if canImport(MLXLLM)
import MLXLLM
import MLXLMCommon
#endif

/// Owns the on-device Gemma model: downloads it on first use (Hugging Face →
/// app container), tracks progress, and holds the loaded `ModelContainer`.
///
/// All MLX usage is behind `#if canImport(MLXLLM)` so the project compiles before
/// the MLX Swift package is added (and on the Simulator, where MLX can't run).
@MainActor
final class GemmaModelManager: ObservableObject {
    static let shared = GemmaModelManager()

    enum State: Equatable {
        case unavailable           // MLX not present (package not added / Simulator)
        case notDownloaded
        case downloading(Double)   // 0...1
        case ready
        case failed(String)
    }

    @Published private(set) var state: State

    private init() {
        #if canImport(MLXLLM)
        state = .notDownloaded
        #else
        state = .unavailable
        #endif
    }

    var isReady: Bool { state == .ready }

    #if canImport(MLXLLM)
    private var container: ModelContainer?

    /// Download (if needed) and load the model, publishing progress.
    func prepare() async {
        if isReady { return }
        state = .downloading(0)
        do {
            // Gemma's turn terminator is `<end_of_turn>`. Loaded by raw id it
            // isn't registered as a stop token, so generation runs away and emits
            // it as literal text — register it explicitly as an extra EOS token.
            let configuration = ModelConfiguration(
                id: GemmaConfig.modelID,
                extraEOSTokens: ["<end_of_turn>"]
            )
            let loaded = try await LLMModelFactory.shared.loadContainer(configuration: configuration) { progress in
                Task { @MainActor in self.state = .downloading(progress.fractionCompleted) }
            }
            container = loaded
            state = .ready
        } catch {
            state = .failed(error.localizedDescription)
        }
    }

    func loadedContainer() -> ModelContainer? { container }

    func delete() {
        container = nil
        state = .notDownloaded
        // NOTE: to reclaim disk, also remove the Hugging Face cache directory
        // used by the loader (under the app's caches), then call prepare() again.
    }
    #else
    func prepare() async {}
    func delete() {}
    #endif
}
