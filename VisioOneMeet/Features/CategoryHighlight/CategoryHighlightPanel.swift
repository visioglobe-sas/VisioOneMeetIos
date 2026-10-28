import SwiftUI

/// Lets the user pick one of the venue's categories (`venue.categories`) and
/// highlight every POI belonging to it in one action, via
/// `venue.pois.filter(poi => poi.categories.some(...))` +
/// `venue.updateSurface()`. Rows show each category's translated display
/// name (`MapCategory.label`), while selection/highlighting is keyed off its
/// raw `id` -- the two differ on this app's shared demo map (see
/// docs/features/category-highlight.md). Picking a different category
/// automatically reverts the previous one first (enforced JS-side, see
/// `features/category-highlight.js`); picking the already-selected category,
/// or tapping "Clear", reverts to no highlight.
struct CategoryHighlightPanel: View {
    @ObservedObject var model: CategoryHighlightModel
    @State private var categories: [MapCategory] = []
    @State private var isLoading = true
    @State private var loadFailed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else if loadFailed {
                Text("Could not load categories")
                    .foregroundStyle(.red)
                    .padding()
            } else if categories.isEmpty {
                Text("No categories on this map")
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                List(categories) { category in
                    Button {
                        model.select(category)
                    } label: {
                        HStack {
                            Text(category.label)
                            Spacer()
                            if category.id == model.highlightedCategoryId {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                }
                .listStyle(.plain)

                if model.highlightedCategoryId != nil {
                    Button("Clear") {
                        model.clear()
                    }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.bordered)
                    .padding()
                }
            }
        }
        .task {
            await loadCategories()
        }
    }

    private func loadCategories() async {
        isLoading = true
        loadFailed = false
        let result = await model.bridge.getCategories()
        isLoading = false
        if let result {
            categories = result
        } else {
            loadFailed = true
        }
    }
}
