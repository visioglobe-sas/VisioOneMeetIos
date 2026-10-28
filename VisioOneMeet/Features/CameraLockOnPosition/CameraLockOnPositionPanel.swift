import SwiftUI

/// Lets the user lock the camera onto the same simulated tracked position
/// as simulated-position (identical Origin/Destination POI ID + accuracy +
/// Start/Stop UI, via `PositionTrackingControls`), plus a **Recenter camera
/// on position** toggle that calls `view.lockCameraPositionOnTracking`
/// through `VisioOneBridge.setCameraLockOnPosition`. See
/// `docs/features/camera-lock-on-position.md`.
///
/// The toggle has no app-side state of its own: it mirrors
/// `model.isCameraLockedOnPosition`, which the JS side pushes on every SDK
/// `trackingon`/`trackingoff`/`trackingchanged` event. So it shows ON right
/// after Start (`allowTracking = true` locks the camera by itself), flips
/// OFF when the user pans the map (the SDK unlocks by itself), and shows
/// OFF again on Stop (`allowTracking = false`). It is disabled while no
/// simulation is running -- locking onto nothing has no visible effect.
struct CameraLockOnPositionPanel: View {
    @ObservedObject var model: CameraLockOnPositionModel
    @ObservedObject var tracking: PositionTrackingController

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PositionTrackingControls(controller: tracking)

            Divider()

            Toggle(isOn: cameraLockBinding) {
                Text("Recenter camera on position")
            }
            .disabled(!tracking.isSimulating)
        }
        .padding()
    }

    private var cameraLockBinding: Binding<Bool> {
        Binding(
            get: { model.isCameraLockedOnPosition },
            set: { model.bridge.setCameraLockOnPosition($0) }
        )
    }
}
