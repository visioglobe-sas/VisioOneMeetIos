import SwiftUI

/// Lets the user type a Place ID and center the camera on it via
/// `view.goToPOI()`. See docs/features/goto-poi.md.
struct GotoPoiPanel: View {
    @ObservedObject var model: GotoPoiModel

    var body: some View {
        HStack {
            PoiIdField("Place ID", text: $model.poiId)

            Button("Go") {
                model.bridge.goToPOI(model.trimmedPoiId)
            }
            .disabled(model.trimmedPoiId.isEmpty)

            Button("Clear") {
                model.bridge.clearPOI()
            }
        }
        .padding()
    }
}
