# Dynamic POI CRUD

## Description

Creates, edits, and removes a POI at runtime — entirely client-side, without republishing the map in VisioMapEditor — via `venue.createPOI()`, `venue.createLabel()` / `venue.updateLabel()`, and `venue.removePOI()`.

The demo tracks a single dynamic POI at a time. Since a bare POI has no visual footprint of its own (see "Things to know" below), creating one also attaches a `Label` to it so it's actually visible on the map. Because this demo has no "tap the map to place a pin" UI, the new POI's WGS84 position is instead copied from an existing "anchor" POI (resolved by id, same idiom as `goto-poi`/`custom-data`'s Place ID field) — its first label's or marker's `.position`.

## SDK usage

```js
// window.MapBridge, JS side
createDynamicPOI: async function (newId, anchorId, labelText) {
  if (!venue) return { status: 'anchorNotFound' };
  var anchor = venue.pois.find(function (p) { return p.id === anchorId; });
  if (!anchor) return { status: 'anchorNotFound' };
  var position =
    (anchor.labels && anchor.labels[0] && anchor.labels[0].position) ||
    (anchor.markers && anchor.markers[0] && anchor.markers[0].position);
  if (!position) return { status: 'noPosition' };

  var poi;
  try {
    poi = venue.createPOI({ id: newId });
  } catch (e) {
    return { status: 'duplicate' }; // venue.createPOI throws POIAlreadyExistsError
  }

  dynamicPoi = poi;
  dynamicLabel = venue.createLabel({
    poi: poi,
    position: { latitude: position.latitude, longitude: position.longitude, altitude: position.altitude },
    width: 2,
    text: labelText,
  });

  return { status: 'created', id: poi.id };
},
updateDynamicLabelText: function (text) {
  if (!venue || !dynamicLabel) return;
  venue.updateLabel(dynamicLabel, { text: text });
},
removeDynamicPOI: function () {
  if (!venue || !dynamicPoi) return;
  venue.removePOI(dynamicPoi);
  dynamicPoi = null;
  dynamicLabel = null;
},
```

```swift
enum CreateDynamicPOIResult: Equatable {
    case created(id: String)
    case duplicate
    case anchorNotFound
    case noPosition
    case bridgeFailure
}

func createDynamicPOI(newId: String, anchorId: String, labelText: String) async -> CreateDynamicPOIResult {
    guard let webView else { return .bridgeFailure }
    return await withCheckedContinuation { continuation in
        webView.callAsyncJavaScript(
            "return await window.MapBridge.createDynamicPOI(newId, anchorId, labelText);",
            arguments: ["newId": newId, "anchorId": anchorId, "labelText": labelText],
            in: nil,
            in: .page
        ) { result in
            // ... maps { status: 'created' | 'duplicate' | 'anchorNotFound' | 'noPosition', id? }
            // into the enum above
        }
    }
}

func updateDynamicLabelText(_ text: String) {
    webView?.evaluateJavaScript("window.MapBridge.updateDynamicLabelText(\(json))") { _, _ in }
}

func removeDynamicPOI() {
    webView?.evaluateJavaScript("window.MapBridge.removeDynamicPOI()") { _, _ in }
}
```

`venue.createPOI(options: { id: string; floor?: Floor; categories?: Category[] }): POI` creates a bare POI and throws `POIAlreadyExistsError` if `id` is already used in the venue. `venue.createLabel(options: { poi, position, width, height?, text, color?, rotation? }): Label` creates a `Label` attached to a POI, `position` being a WGS84 `{ latitude, longitude, altitude? }`. `venue.updateLabel(label, options: { position?, width?, height?, text?, color?, isVisible? })` edits an existing label in place — used here to change its text after creation. `venue.removePOI(poi: POI): void` removes a POI and cascades to remove every visual element attached to it.

`createDynamicPOI` is called via `WKWebView.callAsyncJavaScript` rather than a plain `evaluateJavaScript` string, the same idiom `docs/features/custom-data.md` uses for `loadCustomData` — declaring the JS function `async` and awaiting its resolved value lets every outcome (success, a duplicate id, an unresolved anchor, a position-less anchor) come back as a normal returned value rather than a thrown `WKJavaScriptExceptionMessage`, even though none of `createPOI`/`createLabel` themselves return a `Promise`. `updateDynamicLabelText` and `removeDynamicPOI` are fire-and-forget one-way calls, same idiom as `highlightCategory`/`clearCategoryHighlight` in `docs/features/category-highlight.md` — neither needs a response.

## Things to know

- **A freshly created POI has no visual representation by itself.** `venue.createPOI()` returns a purely logical id/floor/categories container — its `images`, `labels`, `lines`, `surfaces`, and `markers` are all empty arrays on creation. Nothing appears on the map until at least one visual element (a `Label`, `Image`, `Line`, `Marker`, or `Surface`) is explicitly created and attached to it — this demo always follows `createPOI` with `createLabel` for exactly that reason.
- **`venue.updatePOI(poi, options: { categories })` can only ever change categories.** It is *not* a general-purpose "edit a POI" call — it cannot move a POI, rename it, or touch any attached visual content. This demo doesn't call it at all: editing the dynamic POI's visible label text instead goes through `venue.updateLabel()` directly on the attached `Label`, since that's the only thing actually visible. An integrator who calls `updatePOI` expecting it to reposition a POI or edit its label will see no effect.
- **`venue.removePOI(poi)` cascades: every attached visual element is removed automatically.** Removing a POI that has a `Label` (as this demo's dynamic POI does) removes that label from the view too — there's no need to separately call a label-removal method first. Confirmed live: after `removePOI`, the previously visible label disappears from the map with no further calls.
- **`venue.createPOI({ id })` throws `POIAlreadyExistsError` synchronously on a duplicate id** — it does not silently overwrite or return the existing POI. This demo wraps the call in `try/catch` and reports it as a normal `{ status: 'duplicate' }` outcome rather than letting the exception propagate as a bridge failure.
- **POIs have no direct lat/lng field of their own** (same fact `docs/features/simulated-position.md` documents) — a position can only be read from one of a POI's attached visual elements (`labels[0].position`, `markers[0].position`, `images[0].position`). This demo requires the chosen anchor POI to have at least a label or a marker to copy from; an anchor with none of those (e.g. a category-only logical POI) reports `{ status: 'noPosition' }` rather than crashing.
- The dynamic POI created here does not persist anywhere: it lives only in the SDK's in-memory venue model for the current page load. Reloading the map (or restarting the app) discards it — there is no SDK-side persistence story for runtime-created content, by design (that's exactly the "no republish needed" trade-off this feature demonstrates).

## Learn more

- See `docs/features/custom-data.md` for another feature using `WKWebView.callAsyncJavaScript` to await a JS-side result.
- See `docs/features/simulated-position.md` for the same "read a POI's position from its label/marker" idiom, applied to camera tracking instead of copying.
