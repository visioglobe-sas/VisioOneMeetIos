import SwiftUI

/// Animates a simulated tracked position + accuracy circle back and forth
/// between two POIs: the loop is the shared `PositionTrackingController`,
/// owned here (by the screen) rather than by the panel. See
/// docs/features/simulated-position.md.
@MainActor
final class SimulatedPositionModel: FeatureModel {
    let tracking: PositionTrackingController

    init(bridge: VisioOneBridge) {
        tracking = PositionTrackingController(bridge: bridge)
        bridge.onReload { [weak tracking] in tracking?.stopIfRunning() }
    }

    func makePanel() -> AnyView { AnyView(SimulatedPositionPanel(tracking: tracking)) }

    func screenDidDisappear() {
        tracking.stopIfRunning()
    }
}
