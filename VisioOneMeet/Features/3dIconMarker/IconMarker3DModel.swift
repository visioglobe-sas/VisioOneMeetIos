import SwiftUI

/// One icon at a time. See docs/features/3d-icon-marker.md.
@MainActor
final class IconMarker3DModel: ObservableObject, FeatureModel {
    /// Key under which the JS side stores the single `Image` this demo
    /// places.
    private static let iconImageId = "3d-icon-marker"

    /// 96x96 PNG (blue disc + white star) passed as `createImage`'s `url`.
    /// Any image URL works, including `https://` ones.
    static let iconDataURL = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAGAAAABgCAYAAADimHc4AAACBklEQVR42u3dWW4CMRBFUVbLarOn5JsIqRlsv6FuSfmE0O+IwS7bfbtR1GXdf34/+qMOhg2KcehgGIU+HsMt+DEQ7sHXQqQFXwWRHn4sQkvwkRCt4dsjtAdvDTEtfCuEqeFbIAgv/H/NQzAKfx6CYfhzEIzD70cQf+FFAGxFAEAIEBJ+J4LB7+04gKUIAAgBTEackQBfI4SG34MAgBDAaMIrHuAjBACEAGZTvhUAbyEAIAQwbHrUALyEAAAAcwGMe68V4V8iHAjJHeAI7mqAb0oNcOK1vwYgCP+di1E/334EMcDVRSmewx5gd60COPk6K94Bzy7u1OP4CAqrNQCCQdJ4gAcE0Uh1dPgrASYirB0Ri+dsRoa/A6AdYt+ckNksZn3wpwDSIc7NiprP69cFrwJwBdH3BUo6YLlN+qI2ZGZ7EgAA+AgqD99/ueKA8K0Q0veAxSMk7v+tQnABULQrvQZhQgBVv9gCQb00cXVoUQgOa0MBEALsCitvFlSEMBpAvT9gd0g5TRgATAGMe8Ru/ydul+TJULIBNiGMBlDvlFcE4rkGSISgCsICwOG0FGUIuQDCdaM121ydTs1S/wrJDP8gQN3pu44nJzo1RXLC56h6Ts4FAAROUCd8ELiLBuGDwJ2UCB8E7qhH8BMR4orgQZgdfjJEbRE8ELODd8KgBBjUQRSKuqo/fm7G7BpJ/VcAAAAASUVORK5CYII="

    @Published var anchorPoiId = DemoMap.anchorPoiId
    /// Anchor POI id the icon is currently placed on, `nil` when none is
    /// placed.
    @Published private(set) var placedAnchorId: String?
    /// Orientation applied on the next place and live (via
    /// `venue.updateImage`) to an already placed icon.
    @Published private(set) var orientation: IconOrientation = .facing

    let bridge: VisioOneBridge

    init(bridge: VisioOneBridge) {
        self.bridge = bridge
        bridge.onReload { [weak self] in self?.placedAnchorId = nil }
    }

    func makePanel() -> AnyView { AnyView(IconMarker3DPanel(model: self)) }

    var trimmedAnchorPoiId: String { anchorPoiId.trimmingCharacters(in: .whitespaces) }

    /// Places the icon on `anchorId` (replacing any icon already placed).
    /// On success, `placedAnchorId` reflects it.
    func place(anchorId: String) async -> BridgeResult {
        let result = await bridge.placeIconImage(
            imageId: Self.iconImageId,
            anchorId: anchorId,
            url: Self.iconDataURL,
            orientation: orientation
        )
        if result == .success {
            placedAnchorId = anchorId
        }
        return result
    }

    func setOrientation(_ newValue: IconOrientation) {
        orientation = newValue
        guard bridge.webView != nil, placedAnchorId != nil else { return }
        bridge.updateIconImageOrientation(imageId: Self.iconImageId, orientation: newValue)
    }

    /// Cleared optimistically. No-op if nothing is placed.
    func remove() {
        guard bridge.webView != nil, placedAnchorId != nil else { return }
        placedAnchorId = nil
        bridge.removeIconImage(imageId: Self.iconImageId)
    }
}
