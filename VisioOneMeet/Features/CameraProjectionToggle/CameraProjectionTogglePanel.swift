import SwiftUI

/// Segmented Perspective / Orthographic control. `cameraProjection` is a
/// `createView` option only (`view.cameraProjection` is read-only), so
/// picking the other value recreates the whole map; the control reflects
/// the projection the new view actually reports, and is disabled while the
/// map reloads. See docs/features/camera-projection-toggle.md.
struct CameraProjectionTogglePanel: View {
    @ObservedObject var model: CameraProjectionToggleModel
    @ObservedObject var bridge: VisioOneBridge

    private var selection: Binding<CameraProjection> {
        Binding(
            get: { model.shownProjection },
            set: { bridge.reloadWithCameraProjection($0) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Picker(selection: selection) {
                ForEach(CameraProjection.allCases) { projection in
                    Text(projection.label).tag(projection)
                }
            } label: {
                Text("feature.camera_projection.title")
            }
            .pickerStyle(.segmented)
            .disabled(bridge.loadState != .ready)

            Text("feature.camera_projection.hint")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
    }
}
