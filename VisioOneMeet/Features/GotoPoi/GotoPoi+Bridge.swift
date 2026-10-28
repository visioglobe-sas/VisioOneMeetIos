import Foundation

extension VisioOneBridge {
    /// Centers/zooms the camera on a POI by ID via `view.goToPOI()` (after
    /// `view.goToFloor()` to its floor), and highlights its surfaces (see
    /// `docs/features/goto-poi.md`). Also used by 3d-icon-marker,
    /// custom-text-label and html-overlay-marker to bring what they placed
    /// on screen.
    func goToPOI(_ poiId: String) {
        call("goToPOI", args: [poiId])
    }

    /// Clears whatever highlight `goToPOI` left on the map, without moving
    /// the camera.
    func clearPOI() {
        call("clearPOI")
    }
}
