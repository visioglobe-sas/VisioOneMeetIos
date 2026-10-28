import Combine
import SwiftUI

/// Drives the point-in-polygon check against the zone POI's boundary
/// (`VisioOneBridge.resolveZonePolygon`, backed by `Surface.positions` -- the
/// SDK has no geofencing primitive of its own), and the visual alert
/// (`VisioOneBridge.setZoneAlert`) when the tracked position driven by
/// `tracking` crosses in/out of it. Both live here, on the screen, so the
/// zone and its alerts keep working while the panel is closed. See
/// `docs/features/geofencing.md`.
@MainActor
final class GeofencingModel: ObservableObject, FeatureModel {
    @Published var zonePlaceId = DemoMap.geofenceZoneId
    @Published private(set) var zoneErrorMessage: String?
    @Published private(set) var zonePolygon: [GeoPosition]?
    @Published private(set) var isInsideZone = false

    let bridge: VisioOneBridge
    let tracking: PositionTrackingController
    private var alertPlaceId: String?
    private var trackingStopped: AnyCancellable?

    init(bridge: VisioOneBridge) {
        self.bridge = bridge
        tracking = PositionTrackingController(bridge: bridge)
        tracking.onTick = { [weak self] position in
            self?.handleTrackedPosition(position)
        }
        // The simulation stopped (Stop button, a resolution error): revert
        // the alert, so a stale one never lingers on the map.
        trackingStopped = tracking.$isSimulating
            .dropFirst()
            .removeDuplicates()
            .filter { !$0 }
            .sink { [weak self] _ in self?.resetAlert() }
        bridge.onReload { [weak self] in
            guard let self else { return }
            tracking.stopIfRunning()
            isInsideZone = false
            alertPlaceId = nil
            zonePolygon = nil
            zoneErrorMessage = nil
        }
    }

    func makePanel() -> AnyView { AnyView(GeofencingPanel(model: self, tracking: tracking)) }

    func screenDidDisappear() {
        tracking.stopIfRunning()
    }

    var canSetZone: Bool {
        !zonePlaceId.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func resolveZone() {
        let id = zonePlaceId.trimmingCharacters(in: .whitespaces)
        guard !id.isEmpty else { return }

        resetAlert()
        zonePolygon = nil
        zoneErrorMessage = nil

        Task {
            let zone = await bridge.resolveZonePolygon(id)
            switch zone.result {
            case .success:
                zonePolygon = zone.positions
            case .poiNotFound:
                zoneErrorMessage = String(localized: "Zone POI not found")
            case .noSurface:
                zoneErrorMessage = String(localized: "Zone POI has no surface geometry")
            default:
                zoneErrorMessage = String(localized: "Could not read the zone from the map")
            }
        }
    }

    /// Called on every tracked-position tick (`PositionTrackingController.onTick`)
    /// -- there's no dedicated tracked-position-changed SDK event, so this
    /// piggybacks the existing simulation loop rather than polling
    /// separately. Runs a hand-rolled ray-casting point-in-polygon check
    /// (lat/lng treated as planar x/y, accurate enough at building scale --
    /// the SDK exposes no containment primitive) and only calls
    /// `setZoneAlert` on an actual inside/outside transition.
    func handleTrackedPosition(_ position: GeoPosition) {
        guard let polygon = zonePolygon else { return }
        let inside = Self.contains(polygon: polygon, point: position)
        guard inside != isInsideZone else { return }

        isInsideZone = inside
        let id = zonePlaceId.trimmingCharacters(in: .whitespaces)
        alertPlaceId = id
        bridge.setZoneAlert(id, active: inside)
    }

    /// Reverts whatever alert is currently applied. Called when the position
    /// simulation stops and before resolving a new zone.
    func resetAlert() {
        if isInsideZone, let alertPlaceId {
            bridge.setZoneAlert(alertPlaceId, active: false)
        }
        isInsideZone = false
    }

    private static func contains(polygon: [GeoPosition], point: GeoPosition) -> Bool {
        guard polygon.count >= 3 else { return false }

        var inside = false
        var j = polygon.count - 1
        for i in 0..<polygon.count {
            let vi = polygon[i]
            let vj = polygon[j]
            let intersects = (vi.latitude > point.latitude) != (vj.latitude > point.latitude)
                && point.longitude < (vj.longitude - vi.longitude) * (point.latitude - vi.latitude)
                    / (vj.latitude - vi.latitude) + vi.longitude
            if intersects { inside.toggle() }
            j = i
        }
        return inside
    }
}
