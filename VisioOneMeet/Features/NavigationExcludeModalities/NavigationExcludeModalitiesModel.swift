import SwiftUI

@MainActor
final class NavigationExcludeModalitiesModel: ObservableObject, FeatureModel {
    /// The SDK attribute string for an elevator hop on this app's demo map:
    /// `'lift'`, *not* `'elevator'` (excluding `'elevator'` has no effect).
    /// See `docs/features/navigation-exclude-modalities.md`.
    static let elevatorAttribute = "lift"

    @Published var origin = DemoMap.excludeModalitiesFrom
    @Published var destination = DemoMap.excludeModalitiesTo
    @Published var avoidElevator = false

    let bridge: VisioOneBridge

    init(bridge: VisioOneBridge) {
        self.bridge = bridge
    }

    func makePanel() -> AnyView { AnyView(NavigationExcludeModalitiesPanel(model: self)) }

    var route: (origin: String, destination: String)? {
        OriginDestinationFields.trimmed(origin, destination)
    }

    /// The toggle is only read here, when "Itinerary" is pressed --
    /// flipping it alone does not recompute an already-displayed route.
    /// `isAccessible` is `false`, same choice as compute-navigation.
    func showItinerary() {
        guard let route else { return }
        bridge.computeNavigationExcludingModalities(
            origin: route.origin,
            destination: route.destination,
            isAccessible: false,
            excludedAttributes: avoidElevator ? [Self.elevatorAttribute] : []
        )
    }

    func clear() {
        origin = ""
        destination = ""
        bridge.clearNavigationTrace()
    }
}
