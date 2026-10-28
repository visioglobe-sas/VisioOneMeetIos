import SwiftUI

@MainActor
final class ClickableSurfaceModel: ObservableObject, FeatureModel {
    @Published var poiId = DemoMap.clickableSurfacePlaceId

    let bridge: VisioOneBridge

    init(bridge: VisioOneBridge) {
        self.bridge = bridge
    }

    func makePanel() -> AnyView { AnyView(ClickableSurfacePanel(model: self)) }

    var trimmedPoiId: String { poiId.trimmingCharacters(in: .whitespaces) }
}
