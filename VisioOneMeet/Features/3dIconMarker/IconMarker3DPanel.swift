import SwiftUI

/// Places a custom image (a fixed demo icon) at an anchor POI's position in
/// the 3D scene via `venue.createImage()`, switches its orientation live via
/// `venue.updateImage()`, and removes it via `venue.removeImage()` -- see
/// docs/features/3d-icon-marker.md. After a successful place, the camera
/// moves to the anchor POI via goto-poi's `bridge.goToPOI`. An unknown or
/// position-less anchor POI is shown as a plain status line, not a crash.
struct IconMarker3DPanel: View {
    @ObservedObject var model: IconMarker3DModel
    @State private var isPlacing = false
    @State private var errorMessage: String?

    private var orientation: Binding<IconOrientation> {
        Binding(get: { model.orientation }, set: { model.setOrientation($0) })
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PoiIdField("Anchor POI ID", text: $model.anchorPoiId)
                .disabled(isPlacing)

            Text("Orientation")
                .font(.footnote)
                .foregroundStyle(.secondary)
            Picker("Orientation", selection: orientation) {
                Text("Fixed").tag(IconOrientation.fixed)
                Text("Flat").tag(IconOrientation.flat)
                Text("Facing camera").tag(IconOrientation.facing)
            }
            .pickerStyle(.segmented)

            HStack {
                Button("Place icon") {
                    place()
                }
                .disabled(isPlacing || model.trimmedAnchorPoiId.isEmpty)

                Button("Remove icon", role: .destructive) {
                    errorMessage = nil
                    model.remove()
                }
                .disabled(model.placedAnchorId == nil)
            }
            .buttonStyle(.bordered)

            statusText
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }

    @ViewBuilder
    private var statusText: some View {
        if let errorMessage {
            Text(errorMessage)
                .font(.footnote)
                .foregroundStyle(.red)
        } else if let anchorId = model.placedAnchorId {
            Text("Icon placed on \(anchorId)")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else {
            Text("No icon placed")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func place() {
        let anchor = model.trimmedAnchorPoiId
        guard !anchor.isEmpty else { return }

        isPlacing = true
        errorMessage = nil

        Task {
            let result = await model.place(anchorId: anchor)
            isPlacing = false
            switch result {
            case .success:
                // The anchor sits on an indoor floor, not drawn in the
                // default whole-venue view: reuse goto-poi's camera move
                // (floor switch + view.goToPOI) so the icon is on screen.
                model.bridge.goToPOI(anchor)
            case .poiNotFound:
                errorMessage = String(localized: "POI not found")
            case .noPosition:
                errorMessage = String(localized: "This POI has no position")
            case .sdkError(let message), .bridgeError(let message):
                errorMessage = String(localized: "Could not place the icon: \(message)")
            default:
                errorMessage = String(localized: "Could not place the icon: \(String(describing: result))")
            }
        }
    }
}
