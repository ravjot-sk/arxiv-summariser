import SwiftUI
import SwiftData

struct RootView: View {
    @Environment(\.modelContext) private var modelContext
    @Query private var topicsQuery: [SelectedTopics]

    private var selectedTopics: SelectedTopics? { topicsQuery.first }

    var body: some View {
        Group {
            if let selectedTopics, selectedTopics.hasCompletedOnboarding {
                MainTabView(selectedTopics: selectedTopics)
            } else {
                OnboardingView(selectedTopics: ensureTopics())
            }
        }
        .preferredColorScheme(selectedTopics?.appearance.colorScheme ?? nil)
        .task {
            _ = ensureTopics()
            // Auto-load the chosen on-device model if it's already downloaded,
            // so Gemma summaries work without re-tapping "Download" each launch.
            let engine = SummaryPreferences.engine
            if engine == .gemma || engine == .automatic {
                await GemmaModelManager.shared.autoLoadActiveIfDownloaded()
            }
        }
    }

    @discardableResult
    private func ensureTopics() -> SelectedTopics {
        if let existing = selectedTopics { return existing }
        let new = SelectedTopics()
        modelContext.insert(new)
        try? modelContext.save()
        return new
    }
}

private struct MainTabView: View {
    @Bindable var selectedTopics: SelectedTopics

    var body: some View {
        TabView {
            DigestHomeView(selectedTopics: selectedTopics)
                .tabItem { Label("Today", systemImage: "newspaper") }
            SettingsView(selectedTopics: selectedTopics)
                .tabItem { Label("Settings", systemImage: "gearshape") }
        }
    }
}

private struct OnboardingView: View {
    @Bindable var selectedTopics: SelectedTopics
    @Environment(\.modelContext) private var modelContext

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                VStack(spacing: 8) {
                    Image(systemName: "newspaper.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.tint)
                    Text("Pick your research topics")
                        .font(.title2.bold())
                    Text("Each day we'll summarize the newest arXiv papers in the areas you choose.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .padding()

                TopicPickerView(selectedTopics: selectedTopics)

                Button {
                    selectedTopics.hasCompletedOnboarding = true
                    try? modelContext.save()
                } label: {
                    Text(continueTitle)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
                .controlSize(.large)
                .disabled(!selectedTopics.hasSelection)
                .padding()
            }
            .navigationTitle("Welcome")
            .navigationBarTitleDisplayMode(.inline)
        }
    }

    private var continueTitle: String {
        let count = selectedTopics.categoryIDs.count
        switch count {
        case 0: return "Select at least one topic"
        case 1: return "Continue with 1 topic"
        default: return "Continue with \(count) topics"
        }
    }
}
