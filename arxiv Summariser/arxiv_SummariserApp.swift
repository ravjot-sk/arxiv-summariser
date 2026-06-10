//
//  arxiv_SummariserApp.swift
//  arxiv Summariser
//
//  Created by Ravjot on 28.05.26.
//

import SwiftUI
import SwiftData

@main
struct arxiv_SummariserApp: App {
    let modelContainer: ModelContainer

    init() {
        do {
            modelContainer = try ModelContainer(for: SelectedTopics.self, DailyDigest.self, PaperSummary.self)
        } catch {
            fatalError("Failed to create ModelContainer: \(error)")
        }
        BackgroundRefreshManager.register(modelContainer: modelContainer)
    }

    var body: some Scene {
        WindowGroup {
            RootView()
        }
        .modelContainer(modelContainer)
    }
}
