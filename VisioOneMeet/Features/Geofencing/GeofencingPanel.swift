import SwiftUI

/// Lets the user set a "zone" (an existing POI's surface boundary) and a
/// simulated tracked position (the same Origin/Destination POI ID +
/// accuracy + Start/Stop controls as simulated-position, via the shared
/// `PositionTrackingController`/`PositionTrackingControls`), then highlights
/// that zone's surface(s) whenever the simulated position enters it, and
/// clears the highlight on exit -- the base pattern for contextual indoor
/// notifications (e.g. "you're near a promo"). See
/// `docs/features/geofencing.md`.
struct GeofencingPanel: View {
    @ObservedObject var model: GeofencingModel
    @ObservedObject var tracking: PositionTrackingController

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PoiIdField("Zone POI ID", text: $model.zonePlaceId)

            Button("Set zone") {
                model.resolveZone()
            }
            .disabled(!model.canSetZone)

            if let errorMessage = model.zoneErrorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            } else if model.zonePolygon != nil {
                Text(model.isInsideZone ? "Inside zone" : "Outside zone" as LocalizedStringKey)
                    .font(.footnote)
                    .foregroundStyle(model.isInsideZone ? .red : .secondary)
            }

            Divider()

            PositionTrackingControls(controller: tracking)
        }
        .padding()
    }
}
