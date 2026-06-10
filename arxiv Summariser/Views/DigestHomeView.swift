import SwiftUI
import SwiftData

struct DigestHomeView: View {
    @Bindable var selectedTopics: SelectedTopics
    @Environment(\.modelContext) private var modelContext
    @Query(sort: \DailyDigest.categoryID) private var allDigests: [DailyDigest]

    @State private var isRefreshing = false
    @State private var buildProgress: DigestBuildProgress?
    @State private var selectedKeywords: Set<String> = []

    @State private var overviewText: String?
    @State private var overviewIsAI = false
    @State private var isOverviewLoading = false
    @State private var overviewTask: Task<Void, Never>?
    /// Identifies the inputs the current `overviewText` was generated for, so we only
    /// regenerate when the keyword selection or the underlying papers actually change.
    @State private var overviewSignature: String?
    /// Reduce results cached per keyword-combination, so revisiting a filter is instant.
    @State private var overviewCache: [String: SummaryResult] = [:]

    /// Per-paper "map" phase: generating the cached summaries the overview reduces over.
    @State private var isPreparing = false
    @State private var prepareProgress = ""

    /// Today's digests for the user's selected topics.
    private var todaysDigests: [DailyDigest] {
        let todayKey = DailyDigest.dayFormatter.string(from: .now)
        return allDigests.filter {
            $0.dayKey.hasPrefix(todayKey + "|") && selectedTopics.categoryIDs.contains($0.categoryID)
        }
    }

    /// True when every topic shown today is on its fallback (no genuinely new
    /// papers were submitted today, e.g. on a weekend), so we surface a note.
    private var isShowingFallbackOnly: Bool {
        !todaysDigests.isEmpty && todaysDigests.allSatisfy(\.isFallback)
    }

    /// All papers across today's topics, de-duplicated by id, newest first.
    private var papers: [ArxivPaper] {
        var seen = Set<String>()
        var result: [ArxivPaper] = []
        for paper in todaysDigests.flatMap(\.papers).sorted(by: { $0.published > $1.published }) {
            if seen.insert(paper.id).inserted { result.append(paper) }
        }
        return result
    }

    /// Distinct keywords across all papers, most frequent first.
    private var allKeywords: [String] {
        var counts: [String: Int] = [:]
        for paper in papers {
            for keyword in paper.displayKeywords { counts[keyword, default: 0] += 1 }
        }
        return counts.keys.sorted {
            counts[$0]! != counts[$1]! ? counts[$0]! > counts[$1]! : $0 < $1
        }
    }

    private var filteredPapers: [ArxivPaper] {
        guard !selectedKeywords.isEmpty else { return papers }
        return papers.filter { !Set($0.displayKeywords).isDisjoint(with: selectedKeywords) }
    }

    /// Human-readable description of what the overview currently covers.
    private var overviewScope: String {
        selectedKeywords.isEmpty
            ? "all of today's papers in your topics"
            : selectedKeywords.sorted().joined(separator: ", ")
    }

    /// A stable fingerprint of everything the overview depends on.
    private var currentOverviewSignature: String {
        let keywords = selectedKeywords.sorted().joined(separator: ",")
        let paperIDs = filteredPapers.map(\.id).joined(separator: ",")
        return keywords + "|" + paperIDs
    }

    var body: some View {
        NavigationStack {
            Group {
                if papers.isEmpty {
                    emptyState
                } else {
                    content
                }
            }
            .navigationTitle("Today")
            .navigationDestination(for: ArxivPaper.self) { PaperDetailView(paper: $0) }
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        Task { await refresh() }
                    } label: {
                        if isRefreshing { ProgressView() } else { Image(systemName: "arrow.clockwise") }
                    }
                    .disabled(isRefreshing)
                }
            }
            .task {
                if papers.isEmpty {
                    await refresh()
                } else {
                    await prepareSummaries()
                    scheduleOverview()
                }
            }
            .onChange(of: selectedKeywords) { scheduleOverview() }
        }
    }

    private var content: some View {
        VStack(spacing: 0) {
            if let progress = buildProgress {
                buildProgressBar(progress)
                    .padding(.horizontal, 16)
                    .padding(.top, 8)
                    .padding(.bottom, 4)
            }
            keywordBar
            Divider()
            ScrollView {
                LazyVStack(spacing: 12) {
                    if isShowingFallbackOnly {
                        fallbackBanner
                    }
                    overviewBubble
                    if filteredPapers.isEmpty {
                        Text("No papers match the selected keywords.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .padding(.top, 40)
                    } else {
                        ForEach(filteredPapers) { paper in
                            NavigationLink(value: paper) {
                                PaperBubbleView(paper: paper)
                            }
                            .buttonStyle(.plain)
                        }
                    }
                }
                .padding(16)
            }
            .refreshable { await refresh() }
        }
    }

    private var fallbackBanner: some View {
        HStack(spacing: 10) {
            Image(systemName: "clock.arrow.circlepath")
            Text("No new papers today — showing the most recent.")
                .font(.subheadline)
            Spacer(minLength: 0)
        }
        .foregroundStyle(.secondary)
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color(.secondarySystemBackground), in: RoundedRectangle(cornerRadius: 12))
    }

    @ViewBuilder
    private var overviewBubble: some View {
        let loadingMessage: String? = isPreparing
            ? (prepareProgress.isEmpty ? "Summarizing papers…" : prepareProgress)
            : (isOverviewLoading ? "Summarizing…" : nil)
        let card = OverviewBubbleView(
            previewText: overviewText,
            loadingMessage: loadingMessage,
            generatedByAI: overviewIsAI
        )
        if let text = overviewText, loadingMessage == nil {
            NavigationLink {
                OverviewDetailView(text: text, scopeLabel: overviewScope, generatedByAI: overviewIsAI)
            } label: {
                card
            }
            .buttonStyle(.plain)
        } else {
            card
        }
    }

    private var keywordBar: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(allKeywords, id: \.self) { keyword in
                    let isOn = selectedKeywords.contains(keyword)
                    Button {
                        if isOn { selectedKeywords.remove(keyword) }
                        else { selectedKeywords.insert(keyword) }
                    } label: {
                        Text(keyword)
                            .font(.subheadline.weight(.medium))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(
                                isOn ? AnyShapeStyle(.tint) : AnyShapeStyle(Color(.secondarySystemFill)),
                                in: Capsule()
                            )
                            .foregroundStyle(isOn ? Color.white : Color.primary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
    }

    /// A determinate progress bar with a "what's happening + how far" caption,
    /// shared by the initial-load and refresh states.
    @ViewBuilder
    private func buildProgressBar(_ progress: DigestBuildProgress) -> some View {
        let position = progress.currentCategory == nil
            ? progress.total
            : min(progress.completed + 1, progress.total)
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text(progressTitle(progress))
                    .font(.subheadline.weight(.medium))
                    .lineLimit(1)
                Spacer(minLength: 8)
                Text("\(position)/\(progress.total)")
                    .font(.subheadline)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
            }
            ProgressView(value: progress.fraction)
        }
    }

    private func progressTitle(_ progress: DigestBuildProgress) -> String {
        guard let category = progress.currentCategory else { return "Finishing up…" }
        let name = ArxivCategory.displayName(for: category)
        switch progress.phase {
        case .fetching: return "Fetching \(name)…"
        case .summarizing: return "Summarizing \(name)…"
        }
    }

    @ViewBuilder
    private var emptyState: some View {
        if let progress = buildProgress {
            VStack(spacing: 20) {
                Image(systemName: "newspaper")
                    .font(.system(size: 44))
                    .foregroundStyle(.secondary)
                Text("Loading today's research")
                    .font(.headline)
                buildProgressBar(progress)
                    .frame(maxWidth: 280)
            }
            .padding(32)
        } else {
            ContentUnavailableView {
                Label("No papers yet", systemImage: "newspaper")
            } description: {
                Text("Pull to refresh to load today's papers.")
            } actions: {
                Button("Refresh now") { Task { await refresh() } }
            }
        }
    }

    private func refresh() async {
        guard !isRefreshing else { return }
        isRefreshing = true
        buildProgress = DigestBuildProgress(
            completed: 0,
            total: selectedTopics.categoryIDs.count,
            currentCategory: nil,
            phase: .fetching
        )
        defer {
            isRefreshing = false
            buildProgress = nil
        }
        // buildToday saves each topic as soon as it's fetched (progressive display)
        // and warms the per-paper summary cache; mirror its progress into the UI.
        let builder = DigestBuilder(modelContext: modelContext)
        await builder.buildToday(categoryIDs: selectedTopics.categoryIDs) { progress in
            buildProgress = progress
        }
        // New papers invalidate previously-built overviews.
        overviewCache.removeAll()
        overviewSignature = nil
        scheduleOverview()
    }

    /// Map phase: make sure every visible paper has a cached on-device summary. Cheap and a
    /// no-op once warm; only the first sight of a paper pays for it.
    private func prepareSummaries() async {
        let store = PaperSummaryStore(modelContext: modelContext)
        guard !store.isWarm(for: papers) else { return }
        isPreparing = true
        defer { isPreparing = false }
        await store.ensureSummaries(for: papers) { done, total in
            prepareProgress = "Summarizing papers… \(done)/\(total)"
        }
    }

    /// Reduce phase: build the overview from the *cached* per-paper summaries of the filtered
    /// papers. Regenerates only when the keyword/paper inputs change, and reuses a per-filter
    /// in-memory cache so toggling back to a previous selection is instant.
    private func scheduleOverview() {
        let signature = currentOverviewSignature

        // The current summary (or the one being produced) already matches these inputs.
        guard signature != overviewSignature else { return }

        overviewTask?.cancel()
        overviewSignature = signature

        if let cached = overviewCache[signature] {
            overviewText = cached.text
            overviewIsAI = cached.generatedByAI
            isOverviewLoading = false
            return
        }

        isOverviewLoading = true
        let papersSnapshot = filteredPapers
        let scope = overviewScope
        overviewTask = Task {
            try? await Task.sleep(for: .milliseconds(300))
            if Task.isCancelled { return }
            let store = PaperSummaryStore(modelContext: modelContext)
            // Defensive — normally already warm from prepareSummaries()/refresh().
            await store.ensureSummaries(for: papersSnapshot)
            if Task.isCancelled { return }
            let result = await SummaryService.shared.combineSummaries(
                store.summaries(for: papersSnapshot),
                scope: scope
            )
            if Task.isCancelled { return }
            overviewText = result.text
            overviewIsAI = result.generatedByAI
            overviewCache[signature] = result
            isOverviewLoading = false
        }
    }
}

private struct OverviewBubbleView: View {
    let previewText: String?
    let loadingMessage: String?
    let generatedByAI: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 6) {
                Image(systemName: "sparkles")
                Text("Today's overview")
                    .fontWeight(.semibold)
                Spacer()
                if loadingMessage == nil, previewText != nil {
                    Image(systemName: "chevron.right")
                        .font(.caption.weight(.semibold))
                        .opacity(0.8)
                }
            }
            .font(.subheadline)

            if let loadingMessage {
                HStack(spacing: 8) {
                    ProgressView().tint(.white)
                    Text(loadingMessage).font(.subheadline)
                }
                .opacity(0.95)
            } else {
                Text(previewText.map(SummaryFormatter.plainPreview) ?? "No summary available.")
                    .font(.subheadline)
                    .lineLimit(3)
                    .opacity(0.95)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .foregroundStyle(.white)
        .background(overviewGradient, in: RoundedRectangle(cornerRadius: 16))
    }

    private var overviewGradient: LinearGradient {
        LinearGradient(
            colors: [Color.indigo, Color.purple],
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}
