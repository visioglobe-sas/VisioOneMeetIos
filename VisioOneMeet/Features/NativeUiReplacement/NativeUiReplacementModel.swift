import SwiftUI

/// Reuses floor-selector's model (the native picker and the
/// `floorsChanged` mirror) and ui-part-visibility's model (the SDK UI parts
/// hidden), so the native picker is the very same one, and the SDK widget's
/// switch shows the map's real state. See
/// docs/features/native-ui-replacement.md.
@MainActor
final class NativeUiReplacementModel: FeatureModel {
    let floors: FloorSelectorModel
    let uiParts: UiPartVisibilityModel

    init(bridge: VisioOneBridge) {
        floors = FloorSelectorModel(bridge: bridge)
        uiParts = UiPartVisibilityModel(bridge: bridge)
    }

    func makePanel() -> AnyView { AnyView(NativeUiReplacementPanel(floors: floors, uiParts: uiParts)) }

    /// This feature's whole point is that the SDK's own floor-selector
    /// widget starts hidden, unlike ui-part-visibility (whose 5 switches
    /// leave the SDK's default alone until toggled): hide it explicitly once
    /// `view` exists.
    func mapDidBecomeReady() {
        uiParts.setVisible(.floorSelector, false)
    }
}
