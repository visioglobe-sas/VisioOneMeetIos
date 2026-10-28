import Foundation

extension VisioOneBridge {
    /// Locks/unlocks the camera onto the currently tracked position via
    /// `view.lockCameraPositionOnTracking` (see
    /// `docs/features/camera-lock-on-position.md`). Only has a visible
    /// effect once `view.allowTracking` is already `true` (i.e. a
    /// simulated-position loop is running) -- per the SDK's own doc comment,
    /// setting this while tracking is off is a harmless no-op, not an
    /// exception, so no extra guard is needed on the Swift side either.
    ///
    /// Fire-and-forget: the toggle doesn't follow this call, it follows the
    /// SDK's `trackingchanged` event pushed back as `cameraLockChanged`.
    func setCameraLockOnPosition(_ locked: Bool) {
        call("setCameraLockOnPosition", args: [locked])
    }
}
