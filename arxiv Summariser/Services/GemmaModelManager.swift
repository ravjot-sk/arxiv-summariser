import Foundation
import Combine

#if canImport(MLXLLM)
import MLXLLM
import MLXLMCommon
#endif

/// Manages the on-device Gemma models: which are downloaded, which is loaded in
/// memory (active), downloading/switching/deleting, and disk usage.
///
/// Files land in `<Caches>/models/<repo>` (matching MLX's `defaultHubApi`). All
/// MLX usage is behind `#if canImport(MLXLLM)` so the project builds without the
/// package; on the Simulator MLX can't run, so it's reported unavailable.
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
        #if canImport(MLXLLM)
        if loadedModelID == id {
            container = nil
            loadedModelID = nil
        }
        #endif
        try? FileManager.default.removeItem(at: Self.modelDir(id))
        refreshDownloaded()
    }

    // MARK: - Load / download

    #if canImport(MLXLLM)
    private var container: ModelContainer?

    func loadedContainer() -> ModelContainer? { container }

    private func prepare(_ id: String) async {
        guard workingID == nil else { return }            // one at a time
        if loadedModelID == id { setActive(id); return }  // already loaded

        failure = nil
        workingID = id
        progress = isDownloaded(id) ? 1 : 0
        defer { workingID = nil }

        do {
            // Register Gemma's <end_of_turn> as a stop token (else runaway output).
            let configuration = ModelConfiguration(id: id, extraEOSTokens: ["<end_of_turn>"])
            let loaded = try await LLMModelFactory.shared.loadContainer(configuration: configuration) { progress in
                Task { @MainActor in self.progress = progress.fractionCompleted }
            }
            container = loaded
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

    /// `<Caches>/models/<repo>` — matches swift-transformers' `localRepoLocation`.
    private static func modelDir(_ id: String) -> URL {
        cachesBase.appending(component: "models").appending(component: id)
    }

    private static func hasWeights(_ id: String) -> Bool {
        let dir = modelDir(id)
        guard let items = try? FileManager.default.contentsOfDirectory(at: dir, includingPropertiesForKeys: nil) else {
            return false
        }
        return items.contains { $0.pathExtension == "safetensors" }
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
