import SwiftUI

/// accessible-mode has no SDK call of its own: compute-navigation's
/// `computeNavigation` with its `isAccessible` option, and
/// navigation-exclude-modalities' `clearNavigationTrace`. See
/// docs/features/accessible-mode.md.
@MainActor
final class AccessibleModeModel: ObservableObject, FeatureModel {
    @Published var origin = DemoMap.accessibleFrom
    @Published var destination = DemoMap.accessibleTo
    @Published var isAccessible = false

    let bridge: VisioOneBridge

    init(bridge: VisioOneBridge) {
        self.bridge = bridge
    }

    func makePanel() -> AnyView { AnyView(AccessibleModePanel(model: self)) }

    var route: (origin: String, destination: String)? {
        OriginDestinationFields.trimmed(origin, destination)
    }

    /// The toggle is only read here, when "Itinerary" is pressed.
    func showItinerary() {
        guard let route else { return }
        bridge.computeNavigation(origin: route.origin, destination: route.destination, isAccessible: isAccessible)
    }

    func clear() {
        origin = ""
        destination = ""
        bridge.clearNavigationTrace()
    }
}
