# Custom Data

## Description

Reads business `CustomData` — free key/value strings such as price, opening hours, or a product reference — attached to a POI in VisioMapEditor, via `venue.refreshCustomData()` and `venue.getPOICustomData(poi)`.

> **Note:** this demo screen loads a map hash different from the rest of the app (`kd9426d8cb3f1c532f22b5bcbd325c280bd351feb`, overriding `map.html`'s hardcoded default via the `?hash=` query param — see `MapWebView.swift`/`Feature.swift`), because the app's shared demo map (`kbae8e6c066cca4b02c2afac2bc963a643d87437a`) has no CustomData published at all (see "Things to know" below). On this dedicated map, the following POI IDs are confirmed to carry real CustomData:
> - `B1` → `{"CSM ID":"BLBLA"}`
> - `B3-UL00-ID0065` → `{"Sensor X":"17718393"}`
> - `B3-UL00-ID0064` → `{"SENSOR":"DDDZEZHJF"}`
>
> The demo screen offers these 3 as quick-select chips above the free-text Place ID field.

## SDK usage

```js
// window.MapBridge, JS side
loadCustomData: async function (poiId) {
  if (!venue) return { found: false };
  try {
    await venue.refreshCustomData();
  } catch (e) {
    // See "Things to know" below: a rejection here just means no CustomData
    // has been published for this venue yet, not a real failure.
  }
  var poi = venue.pois.find(function (p) { return p.id === poiId; });
  if (!poi) return { found: false };
  return { found: true, data: venue.getPOICustomData(poi) };
},
```

```swift
enum CustomDataLookup: Equatable {
    case poiNotFound
    case data([String: String])
}

func loadCustomData(_ poiId: String) async -> CustomDataLookup? {
    guard let webView else { return nil }
    return await withCheckedContinuation { continuation in
        webView.callAsyncJavaScript(
            "return await window.MapBridge.loadCustomData(poiId);",
            arguments: ["poiId": poiId],
            in: nil,
            in: .page
        ) { result in
            switch result {
            case .success(let value):
                guard let payload = value as? [String: Any],
                      let found = payload["found"] as? Bool else {
                    continuation.resume(returning: nil)
                    return
                }
                guard found else {
                    continuation.resume(returning: .poiNotFound)
                    return
                }
                continuation.resume(returning: .data(payload["data"] as? [String: String] ?? [:]))
            case .failure(let error):
                continuation.resume(returning: nil)
            }
        }
    }
}
```

`venue.refreshCustomData(): Promise<void>` and `venue.getPOICustomData(poi: POI): CustomData` (`CustomData = { [key: string]: string }`) are both defined on `Venue`. `refreshCustomData` is the only one of the two that talks to the server; `getPOICustomData` is a synchronous read of whatever `refreshCustomData` last cached.

Note the use of `WKWebView.callAsyncJavaScript` rather than `evaluateJavaScript`: `loadCustomData` is an `async` JS function because it awaits `refreshCustomData()`'s promise, and plain `evaluateJavaScript(_:completionHandler:)` does not wait for a returned `Promise` to settle — it would resolve immediately with the (unresolved) promise object rather than its eventual value. `callAsyncJavaScript` runs the given source as the body of an async function and calls its completion handler once that function's returned promise actually settles, which is what's needed here.

## Things to know

- **`refreshCustomData()` rejects, rather than resolving, when the venue has no CustomData published at all.** Confirmed live against this app's *shared* demo map (hash `kbae8e6c066cca4b02c2afac2bc963a643d87437a`, used by every other feature screen but not this one — see the note above), which currently has no CustomData published: the SDK fetches a `customData.json` for the venue, and when that 404s, `refreshCustomData()`'s promise rejects with `Error: Hash not found` rather than resolving with an empty cache. This is a normal "nothing published yet" outcome, not a real error — `loadCustomData` above wraps the call in `try/catch` and swallows the rejection so the lookup still proceeds (against whatever the cache holds, which stays `{}`), instead of surfacing a `WKJavaScriptExceptionMessage` failure on the Swift side for what is really just an empty-state. An integrator should not treat this rejection as fatal.
- **`refreshCustomData()` is never called automatically.** The SDK does not preload or refresh CustomData when a venue loads — the cache starts as an empty object and stays that way until `refreshCustomData()` has been awaited at least once. Calling `getPOICustomData()` beforehand will not throw, it will just always return `{}`.
- **`getPOICustomData()` always returns an object, never `null`/`undefined`.** A POI with no CustomData published for it, or one looked up before the first successful `refreshCustomData()`, both come back as `{}` — this is a normal empty state, not an error, and should be rendered as "no data" rather than surfaced as a failure.
- **`refreshCustomData()` reloads *all* POIs' CustomData in one call**, not just one POI's — it's a venue-wide cache refresh, not scoped to the POI passed to `getPOICustomData()` afterward. Calling it repeatedly (e.g. once per lookup, as this demo does) is safe but re-fetches the whole set every time; an app doing many lookups in a row would do better to call it once up front and then call `getPOICustomData()` freely afterward.
- **A missing POI and a POI with no CustomData look different but are both normal.** `venue.pois.find(...)` fails silently if `poiId` doesn't match any POI in the loaded map — that's the "POI not found" case, distinct from a resolved POI whose CustomData happens to be `{}`.
- CustomData values are always strings — there's no typed schema. An integrator wanting numeric/typed data (e.g. a numeric price) needs to parse it on their own.

## Learn more

- See `docs/features/goto-poi.md` for another feature that resolves a POI by ID via `venue.pois.find(...)`.
