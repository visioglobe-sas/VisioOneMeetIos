import Foundation

/// The `createView` `cameraProjection` option / read-only
/// `view.cameraProjection` value (see
/// `docs/features/camera-projection-toggle.md`).
enum CameraProjection: String, CaseIterable, Identifiable {
    case perspective
    case orthographic

    var id: String { rawValue }

    var label: LocalizedStringResource {
        switch self {
        case .perspective:
            return "feature.camera_projection.option.perspective"
        case .orthographic:
            return "feature.camera_projection.option.orthographic"
        }
    }
}

extension VisioOneBridge {
    /// Recreates the map with another camera projection: `cameraProjection`
    /// can only be set at `createView` time, so this redoes the whole page
    /// load (see `reloadPage(with:)`), with the new `?cameraProjection=`
    /// query item. No-op for the projection already requested.
    func reloadWithCameraProjection(_ projection: CameraProjection) {
        guard projection != pageOptions.cameraProjection else { return }
        var options = pageOptions
        options.cameraProjection = projection
        reloadPage(with: options)
    }
}
