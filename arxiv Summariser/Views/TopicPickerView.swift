import SwiftUI
import SwiftData

struct TopicPickerView: View {
    @Bindable var selectedTopics: SelectedTopics
    @Environment(\.modelContext) private var modelContext

    @State private var query = ""
    @State private var expandedGroups: Set<String> = []
    @State private var expandedArchives: Set<String> = []

    var body: some View {
        List {
            ForEach(filteredGroups) { group in
                DisclosureGroup(isExpanded: groupBinding(group.name)) {
                    if group.isFlat {
                        ForEach(group.subgroups[0].categories) { categoryRow($0) }
                    } else {
                        ForEach(group.subgroups) { sub in
                            DisclosureGroup(isExpanded: archiveBinding(group.name, sub.name)) {
                                ForEach(sub.categories) { categoryRow($0) }
                            } label: {
                                header(sub.name, count: selectedCount(in: sub.categories), prominent: false)
                            }
                        }
                    }
                } label: {
                    header(group.name, count: selectedCount(in: group), prominent: true)
                }
            }
        }
        .searchable(text: $query, prompt: "Search topics")
    }

    @ViewBuilder
    private func categoryRow(_ category: ArxivCategory) -> some View {
        Button {
            toggle(category.id)
        } label: {
            HStack {
                VStack(alignment: .leading, spacing: 2) {
                    Text(category.displayName)
                        .foregroundStyle(.primary)
                    Text(category.id)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                if isSelected(category.id) {
                    Image(systemName: "checkmark.circle.fill")
                        .foregroundStyle(.tint)
                }
            }
        }
    }

    @ViewBuilder
    private func header(_ title: String, count: Int, prominent: Bool) -> some View {
        HStack {
            Text(title)
                .font(prominent ? .headline : .subheadline.weight(.medium))
            Spacer()
            if count > 0 {
                Text("\(count)")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.tint)
            }
        }
    }

    // MARK: - Expansion state

    private var isSearching: Bool {
        !query.trimmingCharacters(in: .whitespaces).isEmpty
    }

    /// While searching, every group/archive is forced open so matches are visible.
    private func groupBinding(_ name: String) -> Binding<Bool> {
        Binding(
            get: { isSearching || expandedGroups.contains(name) },
            set: { expanded in
                if expanded { expandedGroups.insert(name) } else { expandedGroups.remove(name) }
            }
        )
    }

    private func archiveBinding(_ group: String, _ archive: String) -> Binding<Bool> {
        let key = "\(group)/\(archive)"
        return Binding(
            get: { isSearching || expandedArchives.contains(key) },
            set: { expanded in
                if expanded { expandedArchives.insert(key) } else { expandedArchives.remove(key) }
            }
        )
    }

    // MARK: - Filtering

    private var filteredGroups: [ArxivCategory.Group] {
        let trimmed = query.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return ArxivCategory.groups }
        return ArxivCategory.groups.compactMap { group in
            let subgroups = group.subgroups.compactMap { sub -> ArxivCategory.Subgroup? in
                let matches = sub.categories.filter { isMatch($0, trimmed) }
                return matches.isEmpty ? nil : ArxivCategory.Subgroup(name: sub.name, categories: matches)
            }
            return subgroups.isEmpty ? nil : ArxivCategory.Group(name: group.name, subgroups: subgroups)
        }
    }

    private func isMatch(_ category: ArxivCategory, _ query: String) -> Bool {
        category.displayName.localizedCaseInsensitiveContains(query)
            || category.id.localizedCaseInsensitiveContains(query)
    }

    // MARK: - Selection

    private func selectedCount(in categories: [ArxivCategory]) -> Int {
        categories.reduce(0) { $0 + (isSelected($1.id) ? 1 : 0) }
    }

    private func selectedCount(in group: ArxivCategory.Group) -> Int {
        group.subgroups.reduce(0) { $0 + selectedCount(in: $1.categories) }
    }

    private func isSelected(_ id: String) -> Bool {
        selectedTopics.categoryIDs.contains(id)
    }

    private func toggle(_ id: String) {
        if let index = selectedTopics.categoryIDs.firstIndex(of: id) {
            selectedTopics.categoryIDs.remove(at: index)
        } else {
            selectedTopics.categoryIDs.append(id)
        }
        try? modelContext.save()
    }
}
