# Geofencing

## Description

Highlights a zone — an existing POI's surface boundary — whenever a tracked position enters it, and reverts the highlight on exit. This is the base building block for contextual indoor notifications (e.g. "you're entering a promo zone"). It's built entirely on top of two other SDK primitives, `Surface.positions` (zone geometry) and `view.injectTrackedPosition()` (position, see `docs/features/simulated-position.md`) — the SDK has no dedicated geofencing/point-in-polygon method, so this demo runs its own containment check in app code.

## SDK usage

```js
// window.MapBridge, JS side
resolveZonePolygon: function (poiId) {
  if (!venue) return { status: 'notFound' };
  var poi = venue.pois.find(function (p) { return p.id === poiId; });
  if (!poi) return { status: 'notFound' };
  var surface = (poi.surfaces || []).find(function (s) { return s.positions && s.positions.length >= 3; });
  if (!surface) return { status: 'noSurface' };
  return {
    status: 'ok',
    positions: surface.positions.map(function (p) { return { latitude: p.latitude, longitude: p.longitude }; }),
  };
},
setZoneAlert: function (placeId, active) {
  if (!venue) return;
  var poi = venue.pois.find(function (p) { return p.id === placeId; });
  if (!poi) return;
  poi.surfaces.forEach(function (surface) {
    venue.updateSurface(surface, { color: active ? '#FF3B30' : 'initial' });
  });
},
```

```swift
func resolveZonePolygon(_ poiId: String) async -> ResolveZoneResult {
    // evaluateJavaScript("window.MapBridge.resolveZonePolygon(...)"), reading
    // { status: 'notFound' | 'noSurface' | 'ok', positions? }
}

func setZoneAlert(_ placeId: String, active: Bool) {
    webView?.evaluateJavaScript("window.MapBridge.setZoneAlert(\(json), \(active))")
}

// On every simulated tracked-position tick:
private static func contains(polygon: [GeoPosition], point: GeoPosition) -> Bool {
    // standard ray-casting point-in-polygon, lat/lng treated as planar x/y
}
```

## Things to know

- **The SDK has no geofencing or point-in-polygon primitive.** A zone is just an existing POI's `Surface`, whose public `positions` field is a WGS84 (`{latitude, longitude, altitude?}`) polygon — the exact same coordinate space `injectTrackedPosition()` takes, so no conversion is needed between "where the zone is" and "where the tracked position is". Containment itself (ray-casting here) is entirely app-side code.
- **There's no tracked-position-changed event to react to.** `view.latestTrackedPosition` is readable but there's no `trackedpositionchanged`-style event, so this demo piggybacks the containment check onto the existing simulated-position tick loop (see `docs/features/simulated-position.md`) rather than polling separately.
- A POI can have several `surfaces`; this demo picks the first one with at least 3 `positions` (a real polygon) as "the zone" and ignores the rest — a POI with only point/marker surfaces (no polygon) is reported as having no usable geometry.
- `venue.updateSurface(surface, { color: 'initial' })` is what actually restores the surface's original bundle-defined color — passing `undefined` or omitting `color` does not.

## Learn more

- See `docs/features/simulated-position.md` for the tracked-position simulation this feature reacts to.
- See `docs/features/clickable-surface.md` and `docs/features/category-highlight.md` for the same `venue.updateSurface()` + `'initial'`-to-revert idiom used here for the alert.
