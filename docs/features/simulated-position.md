# Simulated Position

## Description

Animates a simulated tracked position (with a precision circle) moving between two POIs, via `view.injectTrackedPosition(positionTrackerOptions)`. There's no real indoor positioning behind this demo — positions are linearly interpolated between two known points, standing in for a real BLE/Wi-Fi/UWB feed.

## SDK usage

```js
// window.MapBridge, JS side
// A POI has no lat/lng field: read its display position off what is attached to it.
function poiDisplayPosition(poi) {
  var item = poi.labels.find(hasPosition) || poi.images.find(hasPosition) || poi.markers.find(hasPosition);
  if (item) return item.position;
  var surface = poi.surfaces.find(function (s) { return s.positions.length > 0; });
  if (!surface) return null;
  return centroidOf(surface.positions); // average of the surface's latitude/longitude/altitude
}

resolvePoiPosition: function (poiId) {
  var poi = findPoi(poiId); // venue.pois.find(p => p.id === poiId)
  if (!poi) return null;
  var position = poiDisplayPosition(poi);
  if (!position) return null;
  return { latitude: position.latitude, longitude: position.longitude };
},
injectTrackedPosition: function (latitude, longitude, precisionCircleRadius) {
  if (!view) return;
  if (!view.allowTracking) {
    view.allowTracking = true;
  }
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

- **`view.injectTrackedPosition` requires `view.allowTracking = true` beforehand, or the SDK throws.** Turning it on inside `injectTrackedPosition` (rather than as a separate one-time step) avoids having to enforce a call order on the native side, **but only set it when it isn't already `true`**: setting `allowTracking = true` is not side-effect-free, it always forces `lockCameraPositionOnTracking` and `lockCameraOrientationOnTracking` back to `true` (and fires a `trackingon` view event). Re-setting it on every position update re-locks the camera each time, undoing any unlock by the user (a pan) or by your app (see `docs/features/camera-lock-on-position.md`).
- **Drive the position from exactly one loop, and own it outside any transient UI.** The view has a single tracked position: two loops injecting at the same time make the marker jump between both paths, and because `injectTrackedPosition` turns `allowTracking` back on, a leftover loop silently restarts tracking right after you set `allowTracking = false`. This demo keeps the loop in the map screen's state, so closing and reopening the control panel never starts a second one, and stops it when the map screen is left.
- **There's no dedicated "stop" SDK method** — setting `view.allowTracking = false` is what removes the tracked-position marker and precision circle from the map. This is the same mechanism used to stop tracking.
- **A POI has no direct lat/lng field** (there is no `poi.position`). Its position has to be read off the objects attached to it: `poi.labels[].position`, `poi.images[].position`, `poi.markers[].position` (each a `Position` `{ latitude, longitude, altitude? }`), or `poi.surfaces[].positions` (the surface outline). This demo uses one rule everywhere a POI's position is needed: first label, else first image, else first marker, else the centroid (vertex average) of the first surface. A surface-only POI (no label/image/marker) therefore still resolves. If the POI has none of these, or the ID matches no POI, `resolvePoiPosition` returns `null`.
- **`resolvePoiPosition` deliberately doesn't use the JS → native `WKScriptMessageHandler` channel** used elsewhere (see `docs/features/poi-click.md`/`docs/features/loading-state.md`) — it's a synchronous, side-effect-free read, so the direct return value of `evaluateJavaScript(_:completionHandler:)` is enough; no request/response correlation is needed for a lookup this simple.
- **This is a simulated position, not real indoor positioning** — no BLE/Wi-Fi/UWB data is involved, only linear interpolation between two points known in advance. `injectTrackedPosition`/`allowTracking` remain valid as-is if the simulation is later replaced with a real positioning source.

## Learn more

- `view.updatePositionTrackerGraphicOptions({ color, opacity })` customizes the appearance of the tracked-position marker/circle — not demonstrated here.
- See `docs/features/camera-lock-on-position.md` for locking the camera onto this tracked position once it's moving.
