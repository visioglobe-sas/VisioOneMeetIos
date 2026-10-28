import Combine
import SwiftUI

/// A POI tapped on the map, forwarded by the SDK's `poiclick` event
/// (`poiSelected` message, see `features/poi-click.js`). `name` mirrors
/// whatever the SDK resolves as the POI's first label for the current
/// locale -- `nil` if the POI has no label at all. See
/// `docs/features/poi-click.md`.
struct TappedPOI: Equatable {
    let id: String
    let name: String?
}

/// poi-click has no manual trigger: its panel opens by itself on the SDK's
/// own `poiclick` event, so the screen shows a hint instead of a FAB.
@MainActor
final class PoiClickModel: ObservableObject, FeatureModel {
    /// Last POI tapped on the map, `nil` once the reaction panel has been
    /// dismissed.
    @Published private(set) var tappedPOI: TappedPOI?

    init(bridge: VisioOneBridge) {
        bridge.onMessage("poiSelected") { [weak self] payload in
            guard let payload = payload as? [String: Any],
                  let id = payload["id"] as? String else { return }
            self?.tappedPOI = TappedPOI(id: id, name: payload["name"] as? String)
        }
        bridge.onReload { [weak self] in self?.tappedPOI = nil }
    }

    func makePanel() -> AnyView { AnyView(PoiClickPanel(model: self)) }

    /// Built once: the screen subscribes to `requests`.
    private(set) lazy var panelTrigger: PanelTrigger = .automatic(
        requests: $tappedPOI.map { $0 != nil }.removeDuplicates().eraseToAnyPublisher(),
        hint: "Tap a POI on the map"
    )

    /// Resets the panel's source of truth once the user dismisses it, so
    /// tapping the same POI again is still detected as a change (`tappedPOI`
    /// going `nil` -> non-`nil`).
    func panelDidDismiss() {
        tappedPOI = nil
    }
}
