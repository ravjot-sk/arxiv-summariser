import SwiftUI

struct OverviewDetailView: View {
    let text: String
    let scopeLabel: String
    let generatedByAI: Bool

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                    Text(generatedByAI ? "AI summary" : "Summary")
                    Spacer()
                }
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.tint)

                Text("Across \(scopeLabel)")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                SummaryBulletsView(text: text)
            }
            .padding()
        }
        .navigationTitle("Today's Overview")
        .navigationBarTitleDisplayMode(.inline)
    }
}
