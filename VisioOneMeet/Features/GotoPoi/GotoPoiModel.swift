import SwiftUI

@MainActor
final class GotoPoiModel: ObservableObject, FeatureModel {
    @Published var poiId = DemoMap.gotoPoiId

    let bridge: VisioOneBridge

    init(bridge: VisioOneBridge) {
        self.bridge = bridge
    }

    func makePanel() -> AnyView { AnyView(GotoPoiPanel(model: self)) }

    var trimmedPoiId: String { poiId.trimmingCharacters(in: .whitespaces) }
}
