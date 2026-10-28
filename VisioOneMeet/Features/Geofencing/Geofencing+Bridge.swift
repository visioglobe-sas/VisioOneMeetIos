import Foundation

extension VisioOneBridge {
    /// Resolves a zone POI's boundary so the caller can run its own
    /// point-in-polygon check against a simulated tracked position -- the
    /// SDK has no geofencing/containment primitive itself (see
    /// `docs/features/geofencing.md`). `.success` comes with the polygon;
    /// `.poiNotFound` / `.noSurface` / `.bridgeError` without.
    func resolveZonePolygon(_ poiId: String) async -> (result: BridgeResult, positions: [GeoPosition]) {
        let value: Any?
        switch await callForResult("resolveZonePolygon", args: [poiId]) {
        case .success(let result): value = result
        case .failure(let error): return (.bridgeError(error.localizedDescription), [])
        }
        let result = BridgeResult(payload: value)
        guard result == .success else { return (result, []) }
        guard let rawPositions = (value as? [String: Any])?["positions"] as? [[String: Any]] else {
            return (.bridgeError("Unexpected bridge response"), [])
        }
        let positions = rawPositions.compactMap { entry -> GeoPosition? in
            guard let latitude = entry["latitude"] as? Double,
                  let longitude = entry["longitude"] as? Double else { return nil }
            return GeoPosition(latitude: latitude, longitude: longitude)
        }
        return (.success, positions)
    }

    /// Colors/reverts a zone POI's surface(s) as the "inside the geofence"
    /// alert (`venue.updateSurface()` + `'initial'` to revert).
    /// Fire-and-forget, called whenever the caller's point-in-polygon check
    /// flips the inside/outside state.
    func setZoneAlert(_ poiId: String, active: Bool) {
        call("setZoneAlert", args: [poiId, active])
    }
}
