import SwiftUI

@MainActor
final class CategoryHighlightModel: ObservableObject, FeatureModel {
    /// Category id (`venue.categories[].id`) currently highlighted, `nil`
    /// when no category is highlighted. Set optimistically (these are
    /// fire-and-forget one-way calls) rather than round-tripped from JS, and
    /// kept here -- not in the panel -- so it survives the panel being
    /// dismissed and reopened.
    @Published private(set) var highlightedCategoryId: String?

    let bridge: VisioOneBridge

    init(bridge: VisioOneBridge) {
        self.bridge = bridge
        bridge.onReload { [weak self] in self?.highlightedCategoryId = nil }
    }

    func makePanel() -> AnyView { AnyView(CategoryHighlightPanel(model: self)) }

    /// Picking the already-selected category reverts to no highlight.
    func select(_ category: MapCategory) {
        if highlightedCategoryId == category.id {
            clear()
        } else {
            guard bridge.webView != nil else { return }
            highlightedCategoryId = category.id
            bridge.highlightCategory(category.id)
        }
    }

    func clear() {
        guard bridge.webView != nil else { return }
        highlightedCategoryId = nil
        bridge.clearCategoryHighlight()
    }
}
