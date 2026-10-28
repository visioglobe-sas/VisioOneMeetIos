import SwiftUI

/// Lets the user animate a simulated tracked position + accuracy circle
/// back and forth between two POIs via `view.injectTrackedPosition()`. Two
/// Place ID fields resolve to WGS84 positions once at Start (through
/// `VisioOneBridge.resolvePoiPosition`, itself backed by the POIs' own
/// label, image/marker or surface -- see `docs/features/simulated-position.md`),
/// then a repeating Swift-side loop -- `PositionTrackingController`, owned
/// by the screen rather than this sheet -- ping-pongs a linear interpolation
/// between them, independent of whether this sheet stays open.
struct SimulatedPositionPanel: View {
    @ObservedObject var tracking: PositionTrackingController

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PositionTrackingControls(controller: tracking)
        }
        .padding()
    }
}
