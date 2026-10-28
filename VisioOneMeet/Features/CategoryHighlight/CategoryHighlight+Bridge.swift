import Foundation

/// One entry of `venue.categories` (`Category = { readonly id: string }`),
/// returned by `window.MapBridge.getCategories`. `id` is the raw identifier
/// used for filtering/highlighting (a numeric string on this app's shared
/// demo map, e.g. `"9"`) -- not itself human-readable -- while `label` is the
/// display name resolved JS-side via `venue.translator.translateCategory()`
/// (e.g. `"Shops"`). See `docs/features/category-highlight.md`.
struct MapCategory: Equatable, Identifiable {
    let id: String
    let label: String
}

extension VisioOneBridge {
    /// Reads the venue's full category list. Returns `nil` on a bridge/JS
    /// failure; an empty array is a normal (if unlikely) "no categories on
    /// this venue" result, not an error.
    func getCategories() async -> [MapCategory]? {
        guard case .success(let value) = await callForResult("getCategories"),
              let payload = value as? [[String: Any]] else { return nil }
        return payload.compactMap { entry -> MapCategory? in
            guard let id = entry["id"] as? String else { return nil }
            return MapCategory(id: id, label: entry["label"] as? String ?? id)
        }
    }

    /// Highlights every POI belonging to `categoryId` via
    /// `venue.pois.filter(...)` + `venue.updateSurface()`, reverting whatever
    /// category was previously highlighted first so only one is ever
    /// highlighted at a time (see `docs/features/category-highlight.md`).
    func highlightCategory(_ categoryId: String) {
        call("highlightCategory", args: [categoryId])
    }

    /// Reverts whatever `highlightCategory` last applied.
    func clearCategoryHighlight() {
        call("clearCategoryHighlight")
    }
}
