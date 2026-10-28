import SwiftUI

@MainActor
final class ComputeNavigationModel: ObservableObject, FeatureModel {
    @Published var origin = DemoMap.itineraryFrom
    @Published var destination = DemoMap.itineraryTo

    let bridge: VisioOneBridge

    init(bridge: VisioOneBridge) {
        self.bridge = bridge
    }

    func makePanel() -> AnyView { AnyView(ComputeNavigationPanel(model: self)) }

    var route: (origin: String, destination: String)? {
        OriginDestinationFields.trimmed(origin, destination)
    }

    /// `isAccessible` is `false` here, to keep this a minimal demonstration
    /// of the call (accessible-mode has the toggle).
    func showItinerary() {
        guard let route else { return }
        bridge.computeNavigation(origin: route.origin, destination: route.destination, isAccessible: false)
    }
}
