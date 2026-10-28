import SwiftUI

/// The single dynamic POI tracked at a time, mirroring the JS side's own
/// `dynamicPoi`/`dynamicLabel` variables in `features/dynamic-poi-crud.js`.
/// See `docs/features/dynamic-poi-crud.md`.
struct DynamicPOI: Equatable {
    let id: String
    var labelText: String
}

@MainActor
final class DynamicPoiCrudModel: ObservableObject, FeatureModel {
    @Published var newPoiId = DemoMap.newPoiId
    @Published var anchorPoiId = DemoMap.anchorPoiId
    @Published var labelText = DemoMap.dynamicPoiLabelText
    /// The dynamic POI currently on the map, `nil` when none exists. Kept
    /// here -- not in the panel -- so it survives the panel being dismissed
    /// and reopened.
    @Published private(set) var dynamicPOI: DynamicPOI?

    let bridge: VisioOneBridge

    init(bridge: VisioOneBridge) {
        self.bridge = bridge
        bridge.onReload { [weak self] in self?.dynamicPOI = nil }
    }

    func makePanel() -> AnyView { AnyView(DynamicPoiCrudPanel(model: self)) }

    var trimmedNewPoiId: String { newPoiId.trimmingCharacters(in: .whitespaces) }
    var trimmedAnchorPoiId: String { anchorPoiId.trimmingCharacters(in: .whitespaces) }
    var trimmedLabelText: String { labelText.trimmingCharacters(in: .whitespaces) }

    /// Creates the POI; on success, `dynamicPOI` reflects it. Every other
    /// outcome leaves `dynamicPOI` untouched.
    func create(newId: String, anchorId: String, labelText: String) async -> BridgeResult {
        let result = await bridge.createDynamicPOI(newId: newId, anchorId: anchorId, labelText: labelText)
        if result == .success {
            dynamicPOI = DynamicPOI(id: newId, labelText: labelText)
        }
        return result
    }

    /// Updated optimistically (fire-and-forget). No-op if nothing exists.
    func updateText() {
        guard bridge.webView != nil, dynamicPOI != nil else { return }
        dynamicPOI?.labelText = trimmedLabelText
        bridge.updateDynamicLabelText(trimmedLabelText)
    }

    /// Cleared optimistically. No-op if nothing exists.
    func remove() {
        guard bridge.webView != nil, dynamicPOI != nil else { return }
        dynamicPOI = nil
        bridge.removeDynamicPOI()
    }
}
