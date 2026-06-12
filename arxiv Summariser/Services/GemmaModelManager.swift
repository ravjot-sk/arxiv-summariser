import Foundation
import Combine

#if canImport(MLXLLM)
import MLXLLM
import MLXLMCommon
// mlx-swift-lm's loading API takes a hub downloader + tokenizer loader, provided
// by swift-huggingface via the #hubDownloader / #huggingFaceTokenizerLoader macros.
import MLXHuggingFace
import HuggingFace
import Tokenizers
#endif

#if canImport(Gemma4Swift)
import Gemma4Swift
#endif

/// Manages the on-device Gemma models: which are downloaded, which is loaded in
/// memory (active), downloading/switching/deleting, and disk usage.
///
/// MLXLLM models land in swift-huggingface's `HubCache` layout
/// (`<cache>/models--<org>--<repo>/…`); Gemma 4 models land in
/// `<Caches>/models/<repo>` (the Gemma4Swift downloader's layout). All MLX usage
/// is behind `#if canImport(MLXLLM)` so the project builds without the package;
/// on the Simulator MLX can't run, so it's reported unavailable.
@MainActor
final class GemmaModelManager: ObservableObject {
    static let shared = GemmaModelManager()

    /// The user's chosen model (persisted) — loaded automatically on launch.
    @Published private(set) var activeModelID: String
    /// The model currently loaded in memory (nil until loaded).
    @Published private(set) var loadedModelID: String?
    /// The model currently downloading/loading, and its progress.
    @Published private(set) var workingID: String?
    @Published private(set) var progress: Double = 0
    /// Repo ids present on disk, and total bytes they occupy.
    @Published private(set) var downloadedIDs: Set<String> = []
    @Published private(set) var modelsBytes: Int64 = 0
    @Published private(set) var failure: String?

    private static let activeKey = "activeGemmaModel"

    private init() {
        activeModelID = UserDefaults.standard.string(forKey: Self.activeKey) ?? GemmaCatalog.default.id
        refreshDownloaded()
    }

    /// On-device Gemma is usable only with the MLX package on a real device.
    var isMLXAvailable: Bool {
        #if canImport(MLXLLM) && !targetEnvironment(simulator)
        return true
        #else
        return false
        #endif
    }

    /// A model is loaded and ready to generate.
    var isReady: Bool { loadedModelID != nil }

    func isDownloaded(_ id: String) -> Bool { downloadedIDs.contains(id) }

    func bytes(for id: String) -> Int64 { Self.directorySize(Self.modelDir(id)) }

    // MARK: - Actions

    /// Download (if needed), load, and make `id` the active model.
    func use(_ id: String) async { await prepare(id) }

    /// On launch: load the active model if it's already on disk (no tap needed).
    func autoLoadActiveIfDownloaded() async {
        guard isMLXAvailable, loadedModelID == nil, isDownloaded(activeModelID) else { return }
        await prepare(activeModelID)
    }

    func delete(_ id: String) {
        if loadedModelID == id {
            #if canImport(MLXLLM)
            container = nil
            #endif
            #if canImport(Gemma4Swift)
            gemma4Pipeline = nil
            #endif
            loadedModelID = nil
        }
        try? FileManager.default.removeItem(at: Self.modelDir(id))
        refreshDownloaded()
    }

    // MARK: - Load / download

    #if canImport(MLXLLM)
    private var container: ModelContainer?

    func loadedContainer() -> ModelContainer? { container }
    #endif

    #if canImport(Gemma4Swift)
    /// Gemma 4 runs through its own pipeline, not an MLXLLM `ModelContainer`.
    private var gemma4Pipeline: Gemma4Pipeline?

    /// Whether the model currently loaded in memory is a Gemma 4 one.
    var hasGemma4Loaded: Bool { gemma4Pipeline != nil }

    /// Generate on the loaded Gemma 4 pipeline. Stays on this actor (the pipeline
    /// isn't `Sendable`); the heavy MLX work runs asynchronously inside it.
    func gemma4Generate(system: String, prompt: String) async throws -> String {
        guard let pipeline = gemma4Pipeline else { throw GemmaError.notReady }
        return try await pipeline.chat(
            prompt: prompt,
            systemPrompt: system,
            temperature: 0.3,
            maxTokens: 512
        )
    }
    #endif

    #if canImport(MLXLLM)
    private func prepare(_ id: String) async {
        guard workingID == nil else { return }            // one at a time
        if loadedModelID == id { setActive(id); return }  // already loaded

        failure = nil
        workingID = id
        progress = isDownloaded(id) ? 1 : 0
        defer { workingID = nil }

        let runtime = GemmaCatalog.info(for: id)?.runtime ?? .mlxLLM
        do {
            switch runtime {
            case .mlxLLM:
                // Register Gemma's <end_of_turn> as a stop token (else runaway output).
                let configuration = ModelConfiguration(id: id, extraEOSTokens: ["<end_of_turn>"])
                let loaded = try await LLMModelFactory.shared.loadContainer(
                    from: #hubDownloader(),
                    using: #huggingFaceTokenizerLoader(),
                    configuration: configuration
                ) { progress in
                    Task { @MainActor in self.progress = progress.fractionCompleted }
                }
                container = loaded
                #if canImport(Gemma4Swift)
                gemma4Pipeline = nil            // free the other backend
                #endif

            case .gemma4Swift:
                #if canImport(Gemma4Swift)
                // The catalog id is the raw value of a `Gemma4Pipeline.Model` case.
                guard let model = Gemma4Pipeline.Model(rawValue: id) else {
                    throw GemmaError.unavailable
                }
                let pipeline = Gemma4Pipeline()
                // Text-only: drop the vision/audio towers.
                try await pipeline.load(model, multimodal: false, downloadIfNeeded: true) { progress in
                    Task { @MainActor in self.progress = progress.fraction }
                }
                gemma4Pipeline = pipeline
                container = nil                 // free the other backend
                #else
                throw GemmaError.unavailable
                #endif
            }
            loadedModelID = id
            setActive(id)
            refreshDownloaded()
        } catch {
            failure = error.localizedDescription
        }
    }
    #else
    private func prepare(_ id: String) async {}
    #endif

    private func setActive(_ id: String) {
        activeModelID = id
        UserDefaults.standard.set(id, forKey: Self.activeKey)
    }

    // MARK: - Disk

    /// Recompute which catalog models are on disk and how much space they use.
    func refreshDownloaded() {
        var ids: Set<String> = []
        var total: Int64 = 0
        for model in GemmaCatalog.models where Self.hasWeights(model.id) {
            ids.insert(model.id)
            total += Self.directorySize(Self.modelDir(model.id))
        }
        downloadedIDs = ids
        modelsBytes = total
    }

    /// Total bytes of the app's on-disk data container (Documents & Data).
    static func appDataBytes() -> Int64 {
        directorySize(URL(fileURLWithPath: NSHomeDirectory()))
    }

    private static var cachesBase: URL {
        FileManager.default.urls(for: .cachesDirectory, in: .userDomainMask).first!
    }

    /// On-disk location per runtime: MLXLLM models live in the `HubCache` layout
    /// (`<cache>/models--<org>--<repo>/…`), Gemma 4 models in `<Caches>/models/<repo>`
    /// (the Gemma4Swift downloader's layout).
    private static func modelDir(_ id: String) -> URL {
        #if canImport(MLXLLM)
        if GemmaCatalog.info(for: id)?.runtime != .gemma4Swift,
           let repo = Repo.ID(rawValue: id) {
            return HubCache.default.repoDirectory(repo: repo, kind: .model)
        }
        #endif
        return cachesBase.appending(component: "models").appending(component: id)
    }

    private static func hasWeights(_ id: String) -> Bool {
        // Weights can be nested (HubCache stores files under snapshots/<revision>/),
        // so search the whole model directory.
        let dir = modelDir(id)
        guard let enumerator = FileManager.default.enumerator(at: dir, includingPropertiesForKeys: nil) else {
            return false
        }
        for case let fileURL as URL in enumerator where fileURL.pathExtension == "safetensors" {
            return true
        }
        return false
    }

    static func directorySize(_ url: URL) -> Int64 {
        guard let enumerator = FileManager.default.enumerator(
            at: url,
            includingPropertiesForKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey],
            options: []
        ) else { return 0 }
        var total: Int64 = 0
        for case let fileURL as URL in enumerator {
            let values = try? fileURL.resourceValues(forKeys: [.totalFileAllocatedSizeKey, .fileAllocatedSizeKey])
            total += Int64(values?.totalFileAllocatedSize ?? values?.fileAllocatedSize ?? 0)
        }
        return total
    }
}
