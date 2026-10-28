import SwiftUI

/// The projection requested is a page option (`bridge.pageOptions`); the
/// projection the current view actually reports (`view.cameraProjection`,
/// read-only) comes with the `ready` message.
@MainActor
final class CameraProjectionToggleModel: ObservableObject, FeatureModel {
    /// `nil` while loading.
    @Published private(set) var reportedProjection: CameraProjection?

    let bridge: VisioOneBridge

    init(bridge: VisioOneBridge) {
        self.bridge = bridge
        bridge.onMessage("ready") { [weak self] payload in
            guard let raw = (payload as? [String: Any])?["cameraProjection"] as? String else { return }
            self?.reportedProjection = CameraProjection(rawValue: raw)
        }
        bridge.onReload { [weak self] in self?.reportedProjection = nil }
    }

    func makePanel() -> AnyView { AnyView(CameraProjectionTogglePanel(model: self, bridge: bridge)) }

    /// What the control shows: the reported projection, else the requested one.
    var shownProjection: CameraProjection {
        reportedProjection ?? bridge.pageOptions.cameraProjection ?? .perspective
    }
}
