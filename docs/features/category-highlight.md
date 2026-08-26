# Category Highlight

## Description

Highlights every POI belonging to a chosen category (e.g. all restaurants, all shops) in one action, built from `venue.categories`, `poi.categories`, and `venue.updateSurface()`. There is no dedicated "highlight by category" SDK method — this feature is entirely composed from those three primitives.

## SDK usage

```js
// window.MapBridge, JS side
getCategories: function () {
  if (!venue) return [];
  var locale = venue.currentLocale;
  return venue.categories.map(function (c) {
    var translated = venue.translator.translateCategory(c, locale);
    return { id: c.id, label: (translated && translated.name) || c.id };
  });
},
highlightCategory: function (categoryId) {
  if (!venue) return;
  if (highlightedCategoryId) {
    venue.pois
      .filter(function (p) { return p.categories.some(function (c) { return c.id === highlightedCategoryId; }); })
      .forEach(function (poi) {
        poi.surfaces.forEach(function (surface) { venue.updateSurface(surface, { color: 'initial' }); });
      });
  }
  highlightedCategoryId = categoryId;
  venue.pois
    .filter(function (p) { return p.categories.some(function (c) { return c.id === categoryId; }); })
    .forEach(function (poi) {
      poi.surfaces.forEach(function (surface) { venue.updateSurface(surface, { color: '#FF6B00' }); });
    });
},
clearCategoryHighlight: function () {
  if (!venue || !highlightedCategoryId) return;
  venue.pois
    .filter(function (p) { return p.categories.some(function (c) { return c.id === highlightedCategoryId; }); })
    .forEach(function (poi) {
      poi.surfaces.forEach(function (surface) { venue.updateSurface(surface, { color: 'initial' }); });
    });
  highlightedCategoryId = null;
},
```

```swift
func getCategories() async -> [MapCategory]? {
    guard let webView else { return nil }
    return await withCheckedContinuation { continuation in
        webView.evaluateJavaScript("window.MapBridge.getCategories()") { result, error in
            // ... parses the returned [[String: Any]] into [MapCategory]
        }
    }
}

func highlightCategory(_ categoryId: String) {
    guard let webView else { return }
    // ... JSON-encodes categoryId, then:
    webView.evaluateJavaScript("window.MapBridge.highlightCategory(\(json))") { _, error in /* ... */ }
}

func clearCategoryHighlight() {
    webView?.evaluateJavaScript("window.MapBridge.clearCategoryHighlight()") { _, error in /* ... */ }
}
```

`venue.categories: Category[]` (`Category = { readonly id: string }`) is the venue's full category list — a synchronous property already populated once the venue is loaded, no promise involved. **`id` is a raw internal identifier, not itself human-readable** — confirmed live against this app's shared demo map, where it's a numeric string (`"1"` through `"11"`, non-contiguous). The human-readable name (`Buildings`, `Parkings`, `Transportation`, `Workspaces`, `Food and Beverage`, `Toilets`, `Services`, `Shops`, `Gates`, `Wellness and Recreation` on this map) only comes from `venue.translator.translateCategory(category, locale).name` — the same translator API `docs/features/floor-selector.md` already uses for building/floor names. `getCategories` above returns both: `id` for filtering/highlighting, `label` for display.

`poi.categories: Category[]` lists the categories attached to a given POI — a POI can belong to several. The highlight itself is `venue.pois.filter(poi => poi.categories.some(c => c.id === categoryId))` to find the matching POIs, then `poi.surfaces.forEach(surface => venue.updateSurface(surface, { color: HIGHLIGHT_COLOR }))` per POI (this demo uses `#FF6B00`).

`getCategories` is read straight from `evaluateJavaScript`'s own return value on the Swift side (wrapped in `withCheckedContinuation` so callers can `await` it), the same idiom used by `resolvePoiPosition` in `docs/features/simulated-position.md` — it's a synchronous JS computation, not a JS `Promise`, so plain `evaluateJavaScript` (rather than `callAsyncJavaScript`, needed only when the JS side genuinely awaits something — see `docs/features/custom-data.md`) is the right tool. `highlightCategory` and `clearCategoryHighlight` are fire-and-forget one-way calls: neither needs a response, so nothing round-trips back through `WKScriptMessageHandler`.

## Things to know

- **Not every POI has `surfaces`.** Point/marker-only POIs (a single pin with no footprint polygon) have `poi.surfaces === []`, so they simply produce no visible change when their category is highlighted — `updateSurface` is never called for them since the `forEach` has nothing to iterate. Confirmed live on this app's shared demo map: 31 POIs carry at least one category but zero surfaces (e.g. `trainstation01`/`02`/`03`). This is expected, not a bug: a category can be "highlighted" in full even though only some of its members visibly recolor.
- **`venue.updateSurface()`'s effect is confirmed live on the underlying model, not just "no exception thrown."** Reading `surface.color` on a real Shops POI (`B3-UL00-ID0076`, part of the 44-POI `Shops` category on this app's shared demo map) showed `'initial'` before highlighting, `'#FF6B00'` while its category was highlighted, and back to `'initial'` after `clearCategoryHighlight()` — verified with a standalone `WKWebView` harness loading this exact `map.html` + the vendored SDK bundle.
- **`{ color: 'initial' }` is the correct way to revert a surface, not `undefined`/omitting the key.** Per `SurfaceUpdateOptions`'s own doc comment, `'initial'` is the sentinel that restores whatever color the map bundle originally defined for that surface. Leaving `color` out of the options object, or passing `undefined`, does not reset anything — it simply leaves the surface's color untouched, which here would mean a POI stuck highlighted after its category is supposedly cleared. (Same gotcha documented in `docs/features/clickable-surface.md`.)
- **Only one category is highlighted at a time.** `highlightCategory` always reverts whatever `highlightedCategoryId` currently points to before applying the new one, so switching categories never leaves a stale highlight from the previous selection.
- A POI can carry multiple categories (`poi.categories` is an array); such a POI highlights whenever *any* one of its categories is the one currently selected, and reverts when that category is cleared even if the POI also belongs to others.
- `venue.pois.filter(...)` matching zero POIs (an empty or unused category) is a normal, silent no-op — nothing is raised on either side of the bridge.

## Learn more

- See `docs/features/clickable-surface.md` for another feature built on `venue.updateSurface()`, including the same `'initial'` reset gotcha.
- See `docs/features/occupancy-simulated.md` for a simpler, single-POI `venue.updateSurface()` `color` update, without the category-wide fan-out.
