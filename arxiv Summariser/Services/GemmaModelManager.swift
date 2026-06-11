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
            // ⚠️ Verify against the installed mlx-swift-examples version — the
            // factory/loader API has changed across releases.
            let configuration = ModelConfiguration(id: GemmaConfig.modelID)
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
