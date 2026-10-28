import SwiftUI

/// One floor of a `VenueBuilding`, as pushed by the `floorsChanged` bridge
/// message (see `features/floor-selector.js`). `label` is already localized
/// on the JS side (SDK translator), never a raw ID.
struct VenueFloor: Equatable, Identifiable {
    let id: String
    let label: String
}

/// One building of the loaded venue, with its floors sorted top-to-bottom.
struct VenueBuilding: Equatable, Identifiable {
    let id: String
    let label: String
    let floors: [VenueFloor]
}

/// Snapshot of the venue's buildings/floors plus what's currently active,
/// mirrored from the SDK's `view.currentBuilding`/`view.currentFloor`.
/// Empty `buildings` means the SDK hasn't reported anything yet.
struct FloorSelection: Equatable {
    let buildings: [VenueBuilding]
    let currentBuildingId: String?
    let currentFloorId: String?

    static let empty = FloorSelection(buildings: [], currentBuildingId: nil, currentFloorId: nil)
}

/// Buildings/floors of the loaded venue, and which one is currently active,
/// pushed by the JS side on `ready` and on every SDK `currentfloorchanged`
/// event -- whichever triggered it (this app's picker, the SDK's own
/// floor-selector widget, navigation). Also used by native-ui-replacement.
/// See `docs/features/floor-selector.md`.
@MainActor
final class FloorSelectorModel: ObservableObject, FeatureModel {
    @Published private(set) var floorSelection: FloorSelection = .empty

    let bridge: VisioOneBridge

    init(bridge: VisioOneBridge) {
        self.bridge = bridge
        bridge.onMessage("floorsChanged") { [weak self] payload in
            guard let payload = payload as? [String: Any] else { return }
            self?.floorSelection = Self.parseFloorSelection(payload)
        }
        bridge.onReload { [weak self] in self?.floorSelection = .empty }
    }

    func makePanel() -> AnyView { AnyView(FloorSelectorList(model: self)) }

    /// Parses the `floorsChanged` payload sent by `sendFloorsState()` in
    /// `features/floor-selector.js`. Malformed entries are skipped rather
    /// than failing the whole payload, so a single unexpected building
    /// doesn't blank out the rest of the list.
    private static func parseFloorSelection(_ payload: [String: Any]) -> FloorSelection {
        let rawBuildings = payload["buildings"] as? [[String: Any]] ?? []
        let buildings: [VenueBuilding] = rawBuildings.compactMap { raw in
            guard let id = raw["id"] as? String, let label = raw["label"] as? String else { return nil }
            let rawFloors = raw["floors"] as? [[String: Any]] ?? []
            let floors: [VenueFloor] = rawFloors.compactMap { rawFloor in
                guard let floorId = rawFloor["id"] as? String, let floorLabel = rawFloor["label"] as? String else { return nil }
                return VenueFloor(id: floorId, label: floorLabel)
            }
            return VenueBuilding(id: id, label: label, floors: floors)
        }

        return FloorSelection(
            buildings: buildings,
            currentBuildingId: payload["currentBuildingId"] as? String,
            currentFloorId: payload["currentFloorId"] as? String
        )
    }
}
