# React to a POI Tap

## Description

Shows a POI's ID and label when the user taps it on the map, by subscribing to the SDK's `poiclick` event via `view.addEventListener('poiclick', ...)`, and relaying the tapped POI to native code through a `WKScriptMessageHandler`.

## SDK usage

```js
// map.html, once `view` is resolved by createView
view.addEventListener('poiclick', function (event) {
  var poi = event.pois && event.pois[0];
  if (!poi) return;
  window.webkit.messageHandlers.mapBridge.postMessage({
    type: 'poiSelected',
    message: {
      id: poi.id,
      name: poi.labels && poi.labels.length ? poi.labels[0].text : null,
    },
  });
});
```

```swift
// VisioOneBridge.swift, WKScriptMessageHandler
func userContentController(_ c: WKUserContentController, didReceive message: WKScriptMessage) {
    guard let body = message.body as? [String: Any],
          let type = body["type"] as? String else { return }
    switch type {
    case "poiSelected":
        guard let payload = body["message"] as? [String: Any],
              let id = payload["id"] as? String else { return }
        tappedPOI = TappedPOI(id: id, name: payload["name"] as? String)
    default:
        break
    }
}
```

## Things to know

- `event.pois` is the (possibly empty) array of POIs under the tapped point, ordered by proximity to the camera; only the first entry is used here.
- `poi.labels` can be empty even when the POI exists (no label in the current locale) — guard `poi.labels[0].text` accordingly, and treat a `null` name on the native side as expected, not an error.
- `WKScriptMessage.body` only carries property-list-compatible types (`NSString`, `NSNumber`, `NSArray`, `NSDictionary`, `NSNull`, `NSDate`) across the bridge — never force-cast it; fall back silently (`default: break`) on an unexpected shape.
- The SDK's own `poiDetails` UI part still shows its default panel on tap (see `docs/features/ui-part-visibility.md`); this native panel doesn't replace it. Call `view.setUIPartVisible('poiDetails', false)` if the native version should be the only one shown.

## Learn more

- The same JS → native channel (a `WKScriptMessageHandler` receiving `{type, message}`) is reusable for any other SDK event that needs a native reaction (`selectedpoischange`, `currentfloorchanged`, `navigationstarted`, …) — see the SDK's `EventType` definitions.
- See `docs/features/goto-poi.md` for the inverse direction: targeting a POI from native code rather than reacting to a tap.
