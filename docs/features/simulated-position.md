# Simulated Position

## Description

Animates a simulated tracked position (with a precision circle) moving between two POIs, via `view.injectTrackedPosition(positionTrackerOptions)`. There's no real indoor positioning behind this demo — positions are linearly interpolated between two known points, standing in for a real BLE/Wi-Fi/UWB feed.

## SDK usage

```js
// window.MapBridge, JS side
resolvePoiPosition: function (poiId) {
  if (!venue) return null;
  var poi = venue.pois.find(function (p) { return p.id === poiId; });
  if (!poi) return null;
  var position =
    (poi.markers && poi.markers[0] && poi.markers[0].position) ||
    (poi.labels && poi.labels[0] && poi.labels[0].position) ||
    (poi.images && poi.images[0] && poi.images[0].position);
  if (!position) return null;
  return { latitude: position.latitude, longitude: position.longitude };
},
injectTrackedPosition: function (latitude, longitude, precisionCircleRadius) {
  if (!view) return;
  view.allowTracking = true;
  view.injectTrackedPosition({
    position: { latitude: latitude, longitude: longitude },
    precisionCircleRadius: precisionCircleRadius,
  });
},
stopTrackedPosition: function () {
  if (!view) return;
  view.allowTracking = false;
},
```

```swift
struct GeoPosition: Equatable {
    let latitude: Double
    let longitude: Double
}

func resolvePoiPosition(_ poiId: String) async -> GeoPosition? {
    guard let webView else { return nil }
    guard let data = try? JSONSerialization.data(withJSONObject: poiId, options: [.fragmentsAllowed]),
          let json = String(data: data, encoding: .utf8) else { return nil }
    return await withCheckedContinuation { continuation in
        webView.evaluateJavaScript("window.MapBridge.resolvePoiPosition(\(json))") { result, error in
            guard error == nil,
                  let payload = result as? [String: Any],
                  let latitude = payload["latitude"] as? Double,
                  let longitude = payload["longitude"] as? Double else {
                continuation.resume(returning: nil)
                return
            }
            continuation.resume(returning: GeoPosition(latitude: latitude, longitude: longitude))
        }
    }
}

func injectTrackedPosition(latitude: Double, longitude: Double, precisionCircleRadius: Double) {
    webView?.evaluateJavaScript(
        "window.MapBridge.injectTrackedPosition(\(latitude), \(longitude), \(precisionCircleRadius))"
    )
}

func stopTrackedPosition() {
    webView?.evaluateJavaScript("window.MapBridge.stopTrackedPosition()")
}
```

`latitude`/`longitude`/`precisionCircleRadius` are interpolated directly into the JS call rather than JSON-encoded, since they're plain `Double` values computed natively, never user-entered text.

## Things to know

- **`view.injectTrackedPosition` requires `view.allowTracking = true` beforehand, or the SDK throws.** Setting `allowTracking = true` on every call to `injectTrackedPosition` (rather than as a separate one-time step) is idempotent and side-effect-free, which avoids having to enforce a call order on the native side.
- **There's no dedicated "stop" SDK method** — setting `view.allowTracking = false` is what removes the tracked-position marker and precision circle from the map. This is the same mechanism used to stop tracking.
- **A POI has no direct lat/lng field.** Its position must be read from `poi.markers[0].position`, `poi.labels[0].position`, or `poi.images[0].position` (first one available, in that order) — never a `poi.position` field, which doesn't exist. If none of the three exist, or the ID matches no POI, `resolvePoiPosition` returns `null`.
- **`resolvePoiPosition` deliberately doesn't use the JS → native `WKScriptMessageHandler` channel** used elsewhere (see `docs/features/poi-click.md`/`docs/features/loading-state.md`) — it's a synchronous, side-effect-free read, so the direct return value of `evaluateJavaScript(_:completionHandler:)` is enough; no request/response correlation is needed for a lookup this simple.
- **This is a simulated position, not real indoor positioning** — no BLE/Wi-Fi/UWB data is involved, only linear interpolation between two points known in advance. `injectTrackedPosition`/`allowTracking` remain valid as-is if the simulation is later replaced with a real positioning source.

## Learn more

- `view.updatePositionTrackerGraphicOptions({ color, opacity })` customizes the appearance of the tracked-position marker/circle — not demonstrated here.
- See `docs/features/camera-lock-on-position.md` for locking the camera onto this tracked position once it's moving.
