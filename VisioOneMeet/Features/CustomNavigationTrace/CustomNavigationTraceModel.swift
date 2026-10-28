import SwiftUI

/// The 4 fixed color palettes custom-navigation-trace lets a visitor pick
/// for the currently displayed route, applied via
/// `VisioOneBridge.updateNavigationTrace`. `visioglobeBlue` restates the
/// SDK's own documented defaults (`Line.color` `'#0094F0'`, the inactive/
/// preview segment `'#C5C5C5'`) as an explicit preset -- there is no SDK
/// "reset to default" call, see `docs/features/custom-navigation-trace.md` --
/// rather than a fake no-op.
enum NavigationTracePreset: String, CaseIterable, Identifiable {
    case visioglobeBlue
    case brandRed
    case brandGreen
    case brandPurple

    var id: String { rawValue }

    var colors: NavigationTraceColors {
        switch self {
        case .visioglobeBlue:
            return NavigationTraceColors(
                progressColor: "#0094F0",
                progressOutlineColor: "#FFFFFF",
                progressFutureColor: "#C5C5C5",
                previewColor: "#C5C5C5",
                previewOutlineColor: "#FFFFFF"
            )
        case .brandRed:
            return NavigationTraceColors(
                progressColor: "#E53935",
                progressOutlineColor: "#FFFFFF",
                progressFutureColor: "#F8C9C7",
                previewColor: "#F8C9C7",
                previewOutlineColor: "#FFFFFF"
            )
        case .brandGreen:
            return NavigationTraceColors(
                progressColor: "#2E7D32",
                progressOutlineColor: "#FFFFFF",
                progressFutureColor: "#C8E6C9",
                previewColor: "#C8E6C9",
                previewOutlineColor: "#FFFFFF"
            )
        case .brandPurple:
            return NavigationTraceColors(
                progressColor: "#6A1B9A",
                progressOutlineColor: "#FFFFFF",
                progressFutureColor: "#E1BEE7",
                previewColor: "#E1BEE7",
                previewOutlineColor: "#FFFFFF"
            )
        }
    }

    /// Swatch fill color -- the same `progressColor` used in `colors`, the
    /// most visually distinctive part of each preset.
    var swatchColor: Color { Color(hex: colors.progressColor) }

    var label: LocalizedStringKey {
        switch self {
        case .visioglobeBlue: return "VisioGlobe blue"
        case .brandRed: return "Brand red"
        case .brandGreen: return "Brand green"
        case .brandPurple: return "Brand purple"
        }
    }
}

@MainActor
final class CustomNavigationTraceModel: ObservableObject, FeatureModel {
    @Published var origin = DemoMap.itineraryFrom
    @Published var destination = DemoMap.itineraryTo
    /// The preset applied to the trace; it styles the next computed
    /// itinerary too.
    @Published private(set) var tracePreset: NavigationTracePreset = .visioglobeBlue

    let bridge: VisioOneBridge

    init(bridge: VisioOneBridge) {
        self.bridge = bridge
    }

    func makePanel() -> AnyView { AnyView(CustomNavigationTracePanel(model: self)) }

    var route: (origin: String, destination: String)? {
        OriginDestinationFields.trimmed(origin, destination)
    }

    /// compute-navigation's route, then the selected preset on it.
    func showItinerary() {
        guard let route else { return }
        bridge.computeNavigation(origin: route.origin, destination: route.destination, isAccessible: false)
        bridge.updateNavigationTrace(tracePreset.colors)
    }

    /// Re-applies `preset` to whatever trace is already displayed (a
    /// harmless no-op on the JS side before any itinerary exists).
    func select(_ preset: NavigationTracePreset) {
        tracePreset = preset
        bridge.updateNavigationTrace(preset.colors)
    }
}
