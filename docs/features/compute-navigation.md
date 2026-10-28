# Compute a Route

## Description

Computes a route between two POIs given by ID and displays it on the map, via three chained SDK calls: `venue.computeNavigation(request)` (computes the instructions), `venue.createNavigationTrace(navigation)` (creates the visual representation), then `view.setCurrentNavigationTrace(navigationTrace)` (displays it and marks it "current").

## SDK usage

```js
// VisioOneMeet/WebContent/features/compute-navigation.js
computeNavigation: function (request) {
  core.showNavigation(request, undefined);
},

// VisioOneMeet/WebContent/bridge/core.js (shared with
// navigation-exclude-modalities and accessible-mode)
function showNavigation(request, excludedAttributes) {
  if (!venue || !view) return;
  var options = {
    origin: request.origin,
    destination: request.destination,
    isAccessible: request.isAccessible,
    type: 'fastest',
    firstNodeAsIntersection: false,
    mergeFloorChangeInstructions: false,
  };
  if (excludedAttributes) options.excludedAttributes = excludedAttributes;
  var navigationTrace = venue.createNavigationTrace(venue.computeNavigation(options));
  core.currentNavigationTrace = navigationTrace; // kept for custom-navigation-trace
  view.setCurrentNavigationTrace(navigationTrace);
}
```

```swift
// VisioOneMeet/Features/ComputeNavigation/ComputeNavigation+Bridge.swift
func computeNavigation(origin: String, destination: String, isAccessible: Bool) {
    call("computeNavigation", args: [
        ["origin": origin, "destination": destination, "isAccessible": isAccessible],
    ])
}
```

`request.origin`/`request.destination` can be a Place ID (string), a POI, or a `Position` — the SDK type `POIOrIDOrPosition` accepts all three; this call always passes an ID.

## Things to know

- **`view.setCurrentNavigationTrace()` automatically replaces the previous route** — no need to call `view.removeCurrentNavigationTrace()` before computing a new one; the SDK does it internally if a trace was already current.
- **No error is surfaced by default on failure**: `computeNavigation` can throw `RouteNotFoundError`, `SourceOutOfLimitError`, or `DestinationOutOfLimitError` (invalid Place ID, POI outside routing limits, no possible path between the two, etc.). These aren't caught JS-side — they propagate as-is to the `callAsyncJavaScript` completion handler on the Swift side, where `VisioOneBridge.call` only logs them. Surfacing a user-facing message ("route not found") would require a dedicated JS → native error channel (`try`/`catch` around the SDK call, posted back through the message handler), on the same model as the `error`/`poiSelected` messages used elsewhere.
- **No automatic floor change before the call**, unlike `view.goToPOI()` (see `docs/features/goto-poi.md`): `computeNavigation`/`setCurrentNavigationTrace` handle the multi-floor display of the route themselves (floor changes are included in the instructions), and the camera isn't moved automatically — a user may need to navigate manually to the origin's floor to see the start of the trace.
- **`origin`/`destination` must be real Place IDs from the loaded map** — unlike `venue.pois.find(...)` elsewhere in the bridge, an unmatched ID here raises one of the SDK errors above rather than failing silently.
- **`mergeFloorChangeInstructions` has no documented SDK default** (unlike `type: 'fastest'` or `isAccessible: false`), so it's provided explicitly.

## Learn more

- See `docs/features/goto-poi.md` for the other POI-by-ID lookup in this repo, and for the floor pre-change that `computeNavigation` does not need.
- The computed `navigation` object also exposes `navigation.instructions` (turn-by-turn text) if you want to surface written directions in addition to the visual trace.
