# Go to a POI

## Description

Centers and zooms the camera on a POI given its ID, via `view.goToPOI(poi, animationOptions)`. `goToPOI` only moves the camera; this feature also highlights the target POI's surfaces (`selectionColor`) so the result stays visible once the camera arrives, and changes floor beforehand (`view.goToFloor`) when the POI isn't on the current floor.

## SDK usage

```js
// window.MapBridge, JS side
var selectedPoi = null; // currently-highlighted POI, so clearPOI knows what to reset

window.MapBridge = {
  goToPOI: function (poiId) {
    if (!venue || !view) return;
    var poi = venue.pois.find(function (p) { return p.id === poiId; });
    if (!poi) return;

    if (selectedPoi) {
      selectedPoi.surfaces.forEach(function (surface) {
        venue.updateSurface(surface, { selectionColor: undefined });
      });
    }
    selectedPoi = poi;
    poi.surfaces.forEach(function (surface) {
      venue.updateSurface(surface, { selectionColor: '#057DBC' });
    });

    // The SDK is explicit: the caller must change floor before calling
    // goToPOI, otherwise currentFloor/Building stays unchanged.
    var floorChange = poi.floor ? view.goToFloor(poi.floor) : Promise.resolve();
    floorChange.then(function () {
      view.goToPOI(poi, {
        orientation: { pitch: 20 },
        padding: { top: 100, bottom: 100, right: 100, left: 100 },
      });
    });
  },
  clearPOI: function () {
    if (!venue || !selectedPoi) return;
    selectedPoi.surfaces.forEach(function (surface) {
      venue.updateSurface(surface, { selectionColor: undefined });
    });
    selectedPoi = null;
  },
};
```

```swift
func goToPOI(_ poiId: String) {
    guard let webView else { return }
    guard let data = try? JSONSerialization.data(withJSONObject: poiId, options: [.fragmentsAllowed]),
          let json = String(data: data, encoding: .utf8) else { return }
    webView.evaluateJavaScript("window.MapBridge.goToPOI(\(json))")
}

func clearPOI() {
    webView?.evaluateJavaScript("window.MapBridge.clearPOI()")
}
```

`JSONSerialization.data(withJSONObject:options:[.fragmentsAllowed])` encodes a bare `String` directly as a JSON literal — without `.fragmentsAllowed`, `JSONSerialization` rejects a root value that isn't an `Array`/`Dictionary`.

## Things to know

- **`view.goToFloor` before `view.goToPOI` is not optional.** The SDK's own documentation is explicit: "the caller is responsible to call goToFloor prior goToPOI, otherwise the currentFloor/Building will remain active." On a single-floor map this has no visible effect, but targeting a POI on a floor that isn't currently displayed would otherwise move the camera to coordinates that never render.
- `goToFloor`/`goToPOI` both return an `AnimationPromise` (a `Promise<void>` extended with `isCanceled`/`cancel()`), so `.then()` chains directly off them.
- Highlighting via `selectionColor` is a UX addition, not something `goToPOI` provides on its own. Reset the previous highlight (`selectionColor: undefined`) before applying a new one, or the previously targeted POI stays highlighted indefinitely.
- `venue.pois.find(...)` fails silently (no error, no callback) if `poiId` doesn't match any POI in the loaded map.
- Clearing the highlight does not recenter the camera — `clearPOI` only undoes the surface highlight left by `goToPOI`, it doesn't touch the viewpoint (see `docs/features/reset-view.md` for that).

## Learn more

- See `docs/features/floor-selector.md` for the other use of `view.goToFloor()` in this repo.
- See `docs/features/poi-click.md` for the inverse direction: reacting to a tap on the map rather than targeting a POI from native code.
