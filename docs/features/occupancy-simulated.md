# Occupancy (Simulated Data)

## Description

Colors a POI's surface to reflect an occupancy status (free / soon busy / busy), via `venue.updateSurface(surface, { color })`. There's no real sensor behind this demo — a timer cycles through colors as a stand-in for a real IoT/occupancy feed.

## SDK usage

```swift
func updateOccupancy(planId: String, color: String?) {
    guard let webView else { return }
    let entry: [String: Any] = ["planId": planId, "color": color ?? NSNull()]
    guard let data = try? JSONSerialization.data(withJSONObject: [entry]),
          let json = String(data: data, encoding: .utf8) else { return }
    webView.evaluateJavaScript("window.MapBridge.updateOccupancy(\(json))")
}
```

```js
// window.MapBridge, JS side
updateOccupancy: function (occupancy) {
  if (!venue) return;
  occupancy.forEach(function (entry) {
    var poi = venue.pois.find(function (p) { return p.id === entry.planId; });
    if (!poi) return;
    poi.surfaces.forEach(function (surface) {
      venue.updateSurface(surface, { color: entry.color });
    });
  });
},
```

## Things to know

- `venue.pois.find(...)` fails silently if `planId` doesn't match any POI in the loaded map — nothing is raised on either side of the bridge.
- Passing `color: nil` resets the surface to its default appearance. On the Swift side, `JSONSerialization` refuses a raw `nil` inside a dictionary/array, so it must be encoded explicitly as `NSNull()` — otherwise serialization fails silently (`try?` returns `nil`, and the JS call is never sent).
- A POI can have multiple `surfaces`; `updateSurface` is called once per surface so the whole POI footprint changes color, not just one polygon.
- This demonstrates the **mechanism** of a real-time update, not a real IoT integration — a real deployment would replace the timer with a subscription to an actual data source (websocket, API polling) without changing `updateOccupancy` or the SDK call itself.

## Learn more

- `venue.updateSurface()` accepts other style overrides beyond `color` — see the SDK's `Surface`/`SurfaceStyle` types.
