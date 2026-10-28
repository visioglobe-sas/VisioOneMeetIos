import Foundation

extension VisioOneBridge {
    /// Pins an interactive HTML badge on the map via
    /// `venue.createMarker({ poi, position, element })`, owned by the anchor
    /// POI `anchorId` and positioned ~4 m off that POI's display position.
    /// The badge element itself is created by the JS side; its taps come back
    /// as `htmlBadgeTapped` messages. The JS side validates everything (text,
    /// anchor POI, anchor position) before touching an already placed badge,
    /// so a failed place leaves it untouched. See
    /// `docs/features/html-overlay-marker.md`.
    func placeHtmlBadge(anchorId: String, text: String) async -> BridgeResult {
        await callForStatus("placeHtmlBadge", args: [anchorId, text])
    }

    /// Changes the badge text -- a plain DOM edit on the marker's element on
    /// the JS side, no SDK call.
    func updateHtmlBadgeText(_ text: String) async -> BridgeResult {
        await callForStatus("updateHtmlBadgeText", args: [text])
    }

    /// Shows/hides the placed badge via
    /// `venue.updateMarker(marker, { isVisible })`.
    func setHtmlBadgeVisible(_ isVisible: Bool) async -> BridgeResult {
        await callForStatus("setHtmlBadgeVisible", args: [isVisible])
    }

    /// Removes the badge via `venue.removeMarker()` (which also detaches its
    /// element from the DOM); the anchor POI is untouched.
    func removeHtmlBadge() {
        call("removeHtmlBadge")
    }
}
