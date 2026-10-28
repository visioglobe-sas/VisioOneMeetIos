import SwiftUI

/// The POI id field and the last result shown under it, kept here so they
/// are still shown after the panel is reopened. This screen loads a
/// dedicated map (`DemoMap.customDataMapHash`, see `Feature.all`) rather
/// than the app's shared demo map, which has no CustomData published.
@MainActor
final class CustomDataModel: ObservableObject, FeatureModel {
    /// POI ids carrying real CustomData on that map, offered as quick-select
    /// chips; the text field still accepts any other POI ID.
    static let knownPlaceIds = DemoMap.customDataPlaceIds

    @Published var poiId = DemoMap.customDataPlaceId
    @Published var lookup: CustomDataLookup?
    @Published var loadFailed = false

    let bridge: VisioOneBridge

    init(bridge: VisioOneBridge) {
        self.bridge = bridge
    }

    func makePanel() -> AnyView { AnyView(CustomDataPanel(model: self)) }

    var trimmedPoiId: String { poiId.trimmingCharacters(in: .whitespaces) }

    /// Loads `trimmedPoiId`'s CustomData into `lookup` / `loadFailed`.
    func load() async {
        let targetPlaceId = trimmedPoiId
        guard !targetPlaceId.isEmpty else { return }

        loadFailed = false
        lookup = nil
        if let result = await bridge.loadCustomData(targetPlaceId) {
            lookup = result
        } else {
            loadFailed = true
        }
    }
}
