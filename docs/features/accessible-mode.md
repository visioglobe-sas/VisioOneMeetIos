# Accessible Route

## Description

Computes a route the same way as [`compute-navigation`](./compute-navigation.md), but passes `isAccessible: true` to `venue.computeNavigation(request)` so the routing algorithm only uses the venue's own accessible route — for example rerouting through a lift instead of a stairway.

## SDK usage

```js
// window.MapBridge, JS side (already existing computeNavigation handler,
// unchanged for this feature)
computeNavigation: function (request) {
  if (!venue || !view) return;
  var navigation = venue.computeNavigation({
    origin: request.origin,
    destination: request.destination,
    isAccessible: request.isAccessible,
    type: 'fastest',
    firstNodeAsIntersection: false,
    mergeFloorChangeInstructions: false,
  });
  var navigationTrace = venue.createNavigationTrace(navigation);
  currentNavigationTrace = navigationTrace;
  view.setCurrentNavigationTrace(navigationTrace);
},
```

```swift
// VisioOneBridge, native side (already existing computeNavigation method,
// unchanged for this feature)
func computeNavigation(origin: String, destination: String, isAccessible: Bool) {
    guard let webView else { return }
    let request: [String: Any] = ["origin": origin, "destination": destination, "isAccessible": isAccessible]
    guard let data = try? JSONSerialization.data(withJSONObject: request),
          let json = String(data: data, encoding: .utf8) else { return }
    webView.evaluateJavaScript("window.MapBridge.computeNavigation(\(json))")
}
```

`isAccessible?: boolean` sits alongside `computeNavigation`'s other request fields (`origin`, `destination`, `type`, `firstNodeAsIntersection`, `mergeFloorChangeInstructions`), default `false`. Per the SDK's own JSDoc on the parameter:

> If set to true, computed route will only use accessible route.

This feature needed no new bridge/JS method: `isAccessible` was already threaded end-to-end through the existing `computeNavigation` bridge method and JS handler (added for [`compute-navigation`](./compute-navigation.md) and already reused, hardcoded to `false`, by [`navigation-exclude-modalities`](./navigation-exclude-modalities.md)) — this feature is simply the first screen in this app that lets a visitor actually flip it, via a toggle read when "Itinerary" is pressed.

## Things to know

- **`isAccessible` is sugar over the same exclusion mechanism as [`navigation-exclude-modalities`](./navigation-exclude-modalities.md), pre-filled by the venue itself.** Internally, `isAccessible: true` excludes every segment attribute/modality in the venue's own published `accessibleRouteAttributes`/`accessibleRouteModalities` list — the same mechanism `excludedAttributes` uses when passed manually. There is no public getter for these two lists in the SDK's API; they are internal to the routing engine and not inspectable directly.
- **The excluded list is venue-defined, not a fixed SDK constant.** Different venues can (and likely do) publish different `accessibleRouteAttributes`/`accessibleRouteModalities` from VisioMapEditor — what counts as "not accessible" is authored per-venue, not hardcoded in the SDK. Don't assume a specific attribute value without checking (or empirically confirming via routing) on the venue you're integrating against.
- **Confirmed live on this app's shared demo venue:** the default (fastest) route between `B4-UL00-ID0010` and `B4-UL01-ID0014` crosses via a `'stairway'`-tagged segment (`B4-stairs2`); passing `isAccessible: true` for the same pair reroutes the entire path through a `'lift'`-tagged segment (`B4-lift1`) instead — a genuinely different computed route, not just a relabeled one.
- **When no accessible route exists, `computeNavigation` fails exactly like an unreachable origin/destination pair** — it throws the same uncaught `Error` (see [`compute-navigation`](./compute-navigation.md)'s "Things to know" for how that propagates to the `evaluateJavaScript` completion handler on the Swift side). There is no separate error or flag distinguishing "no accessible path exists" from "these two places were never connected at all".
- `isAccessible` is read once per `computeNavigation()` call — toggling it afterward has no effect on an already-computed route; a new call is required to pick up the change.
- `isAccessible: true` and a manually passed `excludedAttributes` (see `navigation-exclude-modalities`) are additive, not exclusive — both can be combined in the same request; the venue's accessible-route exclusions apply on top of whatever else is explicitly excluded.

## Learn more

See [`compute-navigation`](./compute-navigation.md) for the base `computeNavigation` → `createNavigationTrace` → `setCurrentNavigationTrace` sequence this feature builds on, and [`navigation-exclude-modalities`](./navigation-exclude-modalities.md) for the lower-level `excludedAttributes` mechanism `isAccessible` builds on internally.
