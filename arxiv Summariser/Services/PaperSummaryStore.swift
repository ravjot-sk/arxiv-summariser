import Foundation
import SwiftData

/// Fetches and lazily generates per-paper summaries, persisting them so each paper is only
/// summarized once. Used to warm the cache that the dynamic overview reduces over.
@MainActor
struct PaperSummaryStore {
    let modelContext: ModelContext
    let summarizer: SummaryService

    /// Papers per batched summarization request (one Gemini call per chunk).
    private let batchSize = 10

    init(modelContext: ModelContext, summarizer: SummaryService = .shared) {
        self.modelContext = modelContext
        self.summarizer = summarizer
    }

    func cachedSummary(for paperID: String) -> PaperSummary? {
        let descriptor = FetchDescriptor<PaperSummary>(predicate: #Predicate { $0.paperID == paperID })
        return try? modelContext.fetch(descriptor).first
    }

    /// Generate and persist summaries for any papers not yet cached, serially (the on-device
    /// model is a single resource, so parallel calls would only contend).
    func ensureSummaries(for papers: [ArxivPaper], deadline: Date? = nil, onProgress: ((_ done: Int, _ total: Int) -> Void)? = nil) async {
        let missing = papers.filter { cachedSummary(for: $0.id) == nil }
        guard !missing.isEmpty else {
            onProgress?(papers.count, papers.count)
            return
        }

        var done = papers.count - missing.count
        onProgress?(done, papers.count)
        for chunk in missing.chunked(into: batchSize) {
            // Respect an overall deadline (papers are already displayed; this only
            // warms the overview cache, so it's safe to stop early).
            if let deadline, Date() >= deadline { break }

            // One batched request per chunk (a single Gemini call when configured).
            let results = await summarizer.summaries(for: chunk)
            for paper in chunk {
                guard let result = results[paper.id] else { continue }
                modelContext.insert(
                    PaperSummary(paperID: paper.id, summaryText: result.text, generatedByAI: result.generatedByAI)
                )
                done += 1
            }
            try? modelContext.save()
            onProgress?(done, papers.count)
        }
    }

    /// The cached (title, summary) pairs for the given papers, skipping any not yet cached.
    func summaries(for papers: [ArxivPaper]) -> [(title: String, summary: String)] {
        papers.compactMap { paper in
            guard let cached = cachedSummary(for: paper.id) else { return nil }
            return (paper.cleanedTitle, cached.summaryText)
        }
    }

    /// True when every given paper already has a cached summary.
    func isWarm(for papers: [ArxivPaper]) -> Bool {
        papers.allSatisfy { cachedSummary(for: $0.id) != nil }
    }
}
