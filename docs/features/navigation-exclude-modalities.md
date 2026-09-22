# Exclude Modalities

## Description

Adapts a computed route to a given profile by excluding one or more segment "particularities" (e.g. elevators, stairs) from consideration, via `venue.computeNavigation(request)`'s optional `excludedAttributes` parameter — the same call [`compute-navigation`](./compute-navigation.md) already uses, with one extra option. This demo exposes a single "Avoid elevator" toggle, which excludes the `'lift'` attribute.

## SDK usage

```js
// window.MapBridge, JS side
computeNavigationExcludingModalities: function (request) {
  if (!venue || !view) return;
  var navigation = venue.computeNavigation({
    origin: request.origin,
    destination: request.destination,
    isAccessible: request.isAccessible,
    type: 'fastest',
    firstNodeAsIntersection: false,
    mergeFloorChangeInstructions: false,
    excludedAttributes: request.excludedAttributes,
  });
  var navigationTrace = venue.createNavigationTrace(navigation);
  currentNavigationTrace = navigationTrace;
  view.setCurrentNavigationTrace(navigationTrace);
},
```

```swift
// VisioOneBridge, native side
func computeNavigationExcludingModalities(
    origin: String,
    destination: String,
    isAccessible: Bool,
    excludedAttributes: [String]
) {
    guard let webView else { return }
    let request: [String: Any] = [
        "origin": origin,
        "destination": destination,
        "isAccessible": isAccessible,
        "excludedAttributes": excludedAttributes,
    ]
    guard let data = try? JSONSerialization.data(withJSONObject: request),
          let json = String(data: data, encoding: .utf8) else { return }
    webView.evaluateJavaScript("window.MapBridge.computeNavigationExcludingModalities(\(json))")
}
```

`excludedAttributes?: string[]` sits alongside `computeNavigation`'s other request fields (`origin`, `destination`, `isAccessible`, `type`, `firstNodeAsIntersection`, `mergeFloorChangeInstructions`). Each entry is a segment attribute string — a route segment carrying any excluded attribute is treated as unusable by the route computer, the same way `isAccessible: true` rules out segments with a step-only attribute.

This demo adds `computeNavigationExcludingModalities` as its own bridge method rather than an extra parameter on the existing `computeNavigation` bridge method, so the original method's signature never changes for callers that don't need exclusion — the same "add a method, don't change one" idiom [`custom-navigation-trace`](./custom-navigation-trace.md) used for `updateNavigationTrace`.

## Things to know

- **The attribute string for an elevator is `'lift'`, not `'elevator'`.** The SDK's own JSDoc comment on `excludedAttributes` is misleading here — confirmed live against this app's own `map.html` + vendored SDK bundle, on this shared demo venue, with the exact request this feature uses (`origin: 'B1-LL01-ID0013'`, `destination: 'B1-UL02-ID0012'`):
  - No exclusion: 4 instructions, one carrying `attributes: ['lift', 'B1-lift-1']` (a single elevator hop).
  - `excludedAttributes: ['lift']`: 5 instructions, the elevator hop replaced by three separate stairway segments (`['stairway', 'B1-stairs1']`, `['stairway', 'B1-stairs2']`, `['stairway', 'B1-stairs3']`) — a genuinely different, longer route.
  - `excludedAttributes: ['elevator']`: identical to no exclusion at all (still 4 instructions, still the `'lift'` hop) — the route computer doesn't recognize that string, so nothing is actually excluded.

  Don't trust the parameter's own doc comment for the exact string to pass — verify against a real instruction's `attributes` array on your venue instead, since attribute vocabulary is per-map data, not an SDK-wide enum.
- **A route that no longer has a valid path after exclusion still throws, but not with the same message as an unreachable/unknown POI.** Confirmed live on the same venue: excluding every attribute connecting the two floors (`excludedAttributes: ['lift', 'stairway']` on the request above) throws `Error: Cannot compute navigation if no segments are provided in parameters.`, whereas an unresolvable destination ID throws `Error: Cannot compute Navigation as destination is an unknown POI.` — different text, but both are plain, uncaught `Error`s that propagate the same way: neither is caught JS-side, so both surface identically to the `evaluateJavaScript` completion handler on the Swift side (see [`compute-navigation`](./compute-navigation.md)'s "Things to know" for that propagation). Don't rely on the message text to distinguish "exclusion left no route" from any other `computeNavigation` failure.
- **Exclusion only takes effect on the next `computeNavigation()` call** — there's no way to apply/remove an exclusion on a route already displayed; recompute the route to change it, same as changing `origin`/`destination` themselves.
- **`excludedAttributes` is independent of `isAccessible`.** Setting `isAccessible: true` already excludes step-only segments; `excludedAttributes` composes with that rather than replacing it — you can request an accessible route *and* explicitly avoid elevators (or any other attribute) in the same call.

## Learn more

See [`compute-navigation`](./compute-navigation.md) for the base three-call sequence (`computeNavigation` → `createNavigationTrace` → `setCurrentNavigationTrace`) this feature builds on, including the other request fields and their own SDK-thrown error cases.
