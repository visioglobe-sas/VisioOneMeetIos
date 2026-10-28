import SwiftUI

/// Lets the user type a Place ID and toggle its surface(s)' interactivity
/// via `venue.updateSurface()`'s `isInteractive` option. Once enabled, the
/// SDK itself handles the hover/tap color swap directly on the 3D map -- no
/// click listener is wired up on this side, unlike goto-poi's
/// `selectionColor` highlight which is set once and never changes on its
/// own. See docs/features/clickable-surface.md.
struct ClickableSurfacePanel: View {
    @ObservedObject var model: ClickableSurfaceModel

    var body: some View {
        HStack {
            PoiIdField("Place ID", text: $model.poiId)

            Button("Enable") {
                model.bridge.setSurfaceInteractive(model.trimmedPoiId, isInteractive: true)
            }
            .disabled(model.trimmedPoiId.isEmpty)

            Button("Disable") {
                model.bridge.setSurfaceInteractive(model.trimmedPoiId, isInteractive: false)
            }
            .disabled(model.trimmedPoiId.isEmpty)
        }
        .padding()
    }
}
