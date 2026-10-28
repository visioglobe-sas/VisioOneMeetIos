import Foundation

/// The SDK's 3 `Image` orientation modes (`OrientationType`). Raw values
/// match the JS SDK's string literals exactly -- `venue.createImage` throws
/// `"Invalid orientation type"` on anything else. See
/// `docs/features/3d-icon-marker.md`.
enum IconOrientation: String, CaseIterable, Identifiable {
    /// Flat on the ground, fixed heading (`rotation`).
    case fixed
    /// Flat on the ground, turning to face the camera.
    case flat
    /// Billboard, always facing the camera.
    case facing

    var id: String { rawValue }
}

extension VisioOneBridge {
    /// Places the image at `url` in the 3D scene via `venue.createImage()`,
    /// owned by the anchor POI `anchorId` and positioned at that POI's
    /// display position (`poiDisplayPosition` in `bridge/core.js`). The JS
    /// side keeps it under `imageId` (`Image` isn't JSON-serializable, so
    /// only this key crosses the bridge) and removes any image already
    /// stored there first. An unknown POI, a position-less POI, or
    /// `createImage` throwing all come back as normal values.
    func placeIconImage(imageId: String, anchorId: String, url: String, orientation: IconOrientation) async -> BridgeResult {
        await callForStatus("placeIconImage", args: [imageId, anchorId, url, orientation.rawValue])
    }

    /// Applies `orientation` live to the image stored under `imageId` via
    /// `venue.updateImage(image, { orientationType })`.
    func updateIconImageOrientation(imageId: String, orientation: IconOrientation) {
        call("updateIconImageOrientation", args: [imageId, orientation.rawValue])
    }

    /// Removes the image stored under `imageId` via `venue.removeImage()`;
    /// the anchor POI itself is untouched.
    func removeIconImage(imageId: String) {
        call("removeIconImage", args: [imageId])
    }
}
