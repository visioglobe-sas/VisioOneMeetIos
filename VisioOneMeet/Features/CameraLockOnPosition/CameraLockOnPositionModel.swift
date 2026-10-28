import SwiftUI

@MainActor
final class CameraLockOnPositionModel: ObservableObject, FeatureModel {
    /// Mirror of the SDK's `view.lockCameraPositionOnTracking`, pushed by the
    /// JS side on every `trackingon`/`trackingoff`/`trackingchanged` view
    /// event. The SDK moves this on its own -- `allowTracking = true` turns
    /// it on, `allowTracking = false` and a user pan while tracking turn it
    /// off -- so the camera-lock toggle reads this instead of keeping an
    /// independent app-side value. `false` until the first push.
    @Published private(set) var isCameraLockedOnPosition = false

    let bridge: VisioOneBridge
    let tracking: PositionTrackingController

    init(bridge: VisioOneBridge) {
        self.bridge = bridge
        tracking = PositionTrackingController(bridge: bridge)
        bridge.onMessage("cameraLockChanged") { [weak self] payload in
            guard let payload = payload as? [String: Any],
                  let locked = payload["locked"] as? Bool else { return }
            self?.isCameraLockedOnPosition = locked
        }
        bridge.onReload { [weak self] in
            self?.tracking.stopIfRunning()
            self?.isCameraLockedOnPosition = false
        }
    }

    func makePanel() -> AnyView { AnyView(CameraLockOnPositionPanel(model: self, tracking: tracking)) }

    func screenDidDisappear() {
        tracking.stopIfRunning()
    }
}
