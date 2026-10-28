# Occupancy (Simulated Data)

## Description

Colors a POI's surface to reflect an occupancy status (free / soon busy / busy), via `venue.updateSurface(surface, { color })`. There's no real sensor behind this demo — a timer cycles through colors as a stand-in for a real IoT/occupancy feed.

## SDK usage

```swift
// VisioOneMeet/Features/OccupancySimulated/OccupancySimulated+Bridge.swift
func updateOccupancy(poiId: String, color: String?) {
    // `call` passes the arguments as real JS values (callAsyncJavaScript);
    // `nil` arrives as JS `null`.
    call("updateOccupancy", args: [poiId, color])
}
```

```js
// VisioOneMeet/WebContent/features/occupancy-simulated.js
core.register({
  updateOccupancy: function (poiId, color) {
    var venue = core.venue;
    var poi = core.findPoi(poiId); // venue.pois.find(p => p.id === poiId)
    if (!poi) return;
    poi.surfaces.forEach(function (surface) {
      venue.updateSurface(surface, { color: color || 'initial' });
    });
  },
});
```

The timer that cycles the colors lives in `VisioOneMeet/Features/OccupancySimulated/OccupancySimulatedModel.swift`.

## Things to know

- `venue.pois.find(...)` fails silently if `poiId` doesn't match any POI in the loaded map — nothing is raised on either side of the bridge.
- **To reset a surface, pass `color: 'initial'`.** That is what restores the map's own color; `null`/`undefined` does not. Here `color: nil` on the Swift side arrives as `null` (the bridge sends a Swift `nil` as `NSNull()`) and becomes `'initial'` on the JS side.
- A POI can have multiple `surfaces`; `updateSurface` is called once per surface so the whole POI footprint changes color, not just one polygon.
- **Run the update loop from exactly one place that outlives any transient UI** (here the map screen, not the control panel): otherwise reopening the panel can start a second loop and lose the handle needed to stop the first. Stop it, and reset the surface, when the screen goes away.
- This demonstrates the **mechanism** of a real-time update, not a real IoT integration — a real deployment would replace the timer with a subscription to an actual data source (websocket, API polling) without changing `updateOccupancy` or the SDK call itself.

## Learn more

- `venue.updateSurface()` accepts other style overrides beyond `color` — see the SDK's `Surface`/`SurfaceStyle` types.
