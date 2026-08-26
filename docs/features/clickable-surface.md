# Clickable Surface

## Description

Makes a POI's surface(s) interactive, via `venue.updateSurface(surface, options)` with `isInteractive: true`. Once enabled, the SDK itself handles the hover/tap color swap directly on the rendered 3D map — no click listener is wired up on either side of the bridge for that part. This is the base building block for any "availability" use case (a free/occupied room, a parking spot): a real deployment would drive `isInteractive`/`color` from a data feed instead of two buttons, without changing the underlying call.

## SDK usage

```js
// window.MapBridge, JS side
setSurfaceInteractive: function (placeId, isInteractive) {
  if (!venue) return;
  var poi = venue.pois.find(function (p) { return p.id === placeId; });
  if (!poi) return;
  poi.surfaces.forEach(function (surface) {
    venue.updateSurface(
      surface,
      isInteractive
        ? { isInteractive: true, color: '#2ECC71', hoverColor: '#F1C40F', selectionColor: '#E74C3C' }
        : { isInteractive: false, color: 'initial' }
    );
  });
},
```

```swift
func setSurfaceInteractive(_ placeId: String, isInteractive: Bool) {
    guard let webView else { return }
    guard let data = try? JSONSerialization.data(withJSONObject: placeId, options: [.fragmentsAllowed]),
          let json = String(data: data, encoding: .utf8) else { return }
    webView.evaluateJavaScript("window.MapBridge.setSurfaceInteractive(\(json), \(isInteractive))")
}
```

## Things to know

- **`isInteractive: true` is what makes the surface clickable at all** — without it, `hoverColor`/`selectionColor` are accepted but have no effect, since there's nothing for the SDK to swap them in response to. The color swap on hover/tap is entirely SDK-managed once the flag is set: no `poiclick`/pointer event handling is needed on the app side to get the visual feedback.
- **`color` is the idle/base color, distinct from `hoverColor`/`selectionColor`.** `hoverColor` applies while the pointer hovers over the surface (a desktop-only concept — mostly moot on a touch device, but harmless to set) and `selectionColor` applies while the surface is in the SDK's clicked/selected state, which is the visible one on mobile: tapping the surface swaps it to `selectionColor` with no further action from either side of the bridge.
- **Passing `color: 'initial'` (rather than omitting it, or passing `undefined`) resets the surface to whatever color the map bundle originally defined for it.** Disabling interactivity without resetting `color` would leave the surface stuck on whatever custom color was set while it was enabled.
- `hoverColor`/`selectionColor` also each accept the literal `'default'` in addition to a `Color`, falling back to the SDK's own default hover/selection styling rather than a caller-chosen color.
- A POI can have multiple `surfaces` (e.g. an L-shaped room); `updateSurface` is called once per surface via `poi.surfaces.forEach(...)` so the whole POI footprint becomes interactive, not just one polygon.
- `venue.pois.find(...)` fails silently if `placeId` doesn't match any POI in the loaded map — nothing is raised on either side of the bridge.

## Learn more

- See `docs/features/goto-poi.md` for a different, one-shot use of `venue.updateSurface()` (a fixed `selectionColor` highlight set once from native code) versus this feature's SDK-driven, repeated hover/tap swapping.
- See `docs/features/occupancy-simulated.md` for a simpler `venue.updateSurface()` call (`color` only, no interactivity) driving a simulated data feed — this feature's natural next step for a real "availability" use case.
