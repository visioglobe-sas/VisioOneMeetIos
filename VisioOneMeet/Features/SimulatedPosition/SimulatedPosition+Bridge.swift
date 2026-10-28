import Foundation

extension VisioOneBridge {
    /// Resolves a POI's WGS84 display position by ID (first label, else
    /// first image/marker, else first surface's centroid, see
    /// `poiDisplayPosition` in `bridge/core.js`). Returns `nil` if the POI id
    /// doesn't exist or has none of these -- both are "POI not found" to the
    /// caller -- or on a bridge failure. See
    /// `docs/features/simulated-position.md`.
    func resolvePoiPosition(_ poiId: String) async -> GeoPosition? {
        guard case .success(let value) = await callForResult("resolvePoiPosition", args: [poiId]),
              let payload = value as? [String: Any],
              let latitude = payload["latitude"] as? Double,
              let longitude = payload["longitude"] as? Double else { return nil }
        return GeoPosition(latitude: latitude, longitude: longitude)
    }

    /// Injects/updates a simulated tracked position + its accuracy circle via
    /// `view.injectTrackedPosition()`, turning on `view.allowTracking` first
    /// (done JS-side, only when it isn't already on -- re-setting it would
    /// re-lock the camera on every tick, see `features/simulated-position.js`).
    /// Meant to be called repeatedly on a timer by the caller
    /// (`PositionTrackingController`); this method itself is stateless.
    func injectTrackedPosition(latitude: Double, longitude: Double, precisionCircleRadius: Double) {
        call("injectTrackedPosition", args: [latitude, longitude, precisionCircleRadius])
    }

    /// Removes the simulated tracked position from the map via
    /// `view.allowTracking = false` -- the SDK has no dedicated "stop"
    /// method, this is how the marker/accuracy circle is cleared.
    func stopTrackedPosition() {
        call("stopTrackedPosition")
    }
}
