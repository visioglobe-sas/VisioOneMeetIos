import Foundation

extension VisioOneBridge {
    /// Creates a bare POI (id/floor/categories only) via `venue.createPOI()`
    /// and attaches a visible `Label` to it via `venue.createLabel()`,
    /// copying its position from an existing "anchor" POI's display position
    /// (see `docs/features/dynamic-poi-crud.md`). Every outcome -- success, a
    /// duplicate id (`venue.createPOI` throws `POIAlreadyExistsError`), an
    /// unresolved anchor, or an anchor with no position to copy -- comes back
    /// as a normal value: `.success`, `.duplicate`, `.poiNotFound`,
    /// `.noPosition`.
    func createDynamicPOI(newId: String, anchorId: String, labelText: String) async -> BridgeResult {
        await callForStatus("createDynamicPOI", args: [newId, anchorId, labelText])
    }

    /// Updates the dynamic POI's label text via `venue.updateLabel()` -- the
    /// real "edit" story for a dynamic POI, since `venue.updatePOI()` itself
    /// can only ever touch categories. No-op JS-side if none exists.
    func updateDynamicLabelText(_ text: String) {
        call("updateDynamicLabelText", args: [text])
    }

    /// Removes the dynamic POI via `venue.removePOI()`, which cascades to
    /// remove its attached label automatically -- no separate label removal
    /// call is needed. No-op JS-side if none exists.
    func removeDynamicPOI() {
        call("removeDynamicPOI")
    }
}
