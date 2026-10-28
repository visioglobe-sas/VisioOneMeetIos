import SwiftUI

/// Pins an interactive HTML badge on the map via `venue.createMarker()`
/// next to an anchor POI -- a DOM element drawn above the 3D scene, never
/// hidden by geometry, whose taps are forwarded to native and counted here
/// (`model.tapCount`). Text is changed with a plain DOM edit, visibility via
/// `venue.updateMarker(marker, { isVisible })`, removal via
/// `venue.removeMarker()` -- see docs/features/html-overlay-marker.md. After
/// a successful place, the camera moves to the anchor POI via goto-poi's
/// `bridge.goToPOI`, same as custom-text-label. Empty text or an
/// unknown/position-less anchor POI is shown as a plain status line, not a
/// crash.
struct HtmlOverlayMarkerPanel: View {
    @ObservedObject var model: HtmlOverlayMarkerModel
    @State private var isBusy = false
    @State private var errorMessage: String?

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                PoiIdField("Anchor POI ID", text: $model.anchorPoiId)
                    .disabled(isBusy)

                TextField("Badge text", text: $model.text)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .disabled(isBusy)

                HStack {
                    Button("Place badge") {
                        place()
                    }
                    .disabled(isBusy || model.trimmedAnchorPoiId.isEmpty)

                    Button("Update text") {
                        updateText()
                    }
                    .disabled(isBusy || !model.hasBadge)
                }
                .buttonStyle(.bordered)

                HStack {
                    Button(model.isBadgeVisible ? "Hide badge" : "Show badge" as LocalizedStringKey) {
                        toggleVisibility()
                    }
                    .disabled(isBusy || !model.hasBadge)

                    Button("Remove badge", role: .destructive) {
                        errorMessage = nil
                        model.remove()
                    }
                    .disabled(!model.hasBadge)
                }
                .buttonStyle(.bordered)

                statusText
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
    }

    @ViewBuilder
    private var statusText: some View {
        if let errorMessage {
            Text(errorMessage)
                .font(.footnote)
                .foregroundStyle(.red)
        } else if let anchorId = model.placedAnchorId {
            Group {
                if model.tapCount > 0 {
                    Text("Badge tapped (\(model.tapCount))")
                } else {
                    Text("Badge placed on \(anchorId)")
                }
            }
            .font(.footnote)
            .foregroundStyle(.secondary)
        } else {
            Text("No badge placed")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func place() {
        let anchor = model.trimmedAnchorPoiId
        guard !anchor.isEmpty else { return }

        isBusy = true
        errorMessage = nil

        Task {
            let result = await model.place(anchorId: anchor)
            isBusy = false
            if result == .success {
                // The badge is only displayed while its POI's floor is the
                // displayed floor: reuse goto-poi's camera move (floor
                // switch + view.goToPOI), same as custom-text-label.
                model.bridge.goToPOI(anchor)
            } else {
                errorMessage = placedObjectErrorMessage(result, isBadge: true)
            }
        }
    }

    private func updateText() {
        isBusy = true
        errorMessage = nil

        Task {
            let result = await model.updateText()
            isBusy = false
            errorMessage = placedObjectErrorMessage(result, isBadge: true)
        }
    }

    private func toggleVisibility() {
        isBusy = true
        errorMessage = nil

        Task {
            await model.toggleVisibility()
            isBusy = false
        }
    }
}
