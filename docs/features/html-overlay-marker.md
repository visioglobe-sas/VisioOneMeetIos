# HTML overlay marker

## Description

Pins an HTML element — here a small "Open now · 12:00–14:00" badge — on the map at a geographic position via `venue.createMarker({ poi, position, element })`. Unlike a `Label` or an `Image`, which live inside the 3D scene, a marker's element is a regular DOM node drawn on top of the map: it always faces the screen, is never hidden by walls or other 3D geometry, and — the point of this demo — it is **interactive**: tapping it reaches the app. The text is changed with a plain DOM edit, the badge is shown/hidden via `venue.updateMarker(marker, { isVisible })`, and removed via `venue.removeMarker(marker)`.

Every marker must belong to a POI. This demo uses an existing "anchor" POI (resolved by id, `B4-UL00-ID0009` "Restaurant" by default) as the owner, reads that POI's position from its first label or marker (the same lookup as `docs/features/dynamic-poi-crud.md`, `docs/features/3d-icon-marker.md` and `docs/features/custom-text-label.md`), and offsets it by `+0.00004` in latitude and longitude (about 4 m). One badge is tracked at a time. Placing again validates everything first (text, anchor POI, anchor position) and only then replaces the previous badge, so a failed place leaves the existing one untouched.

In this iOS app the element is created by the JS side inside the `WKWebView`; its `click` is forwarded to Swift through the `WKScriptMessageHandler` bridge, where the tap is counted.

## SDK usage

```js
// window.MapBridge, JS side. htmlBadge holds the Marker -- not
// JSON-serializable, so it never crosses the bridge.
var htmlBadge = null;

// First label's, else first marker's .position -- skipping `exclude` (one of our own overlays).
function anchorPositionOf(poi, exclude) {
  var label = (poi.labels || []).find(function (l) { return l !== exclude; });
  var marker = (poi.markers || []).find(function (m) { return m !== exclude; });
  var position = (label && label.position) || (marker && marker.position);
  if (!position) return null;
  return { latitude: position.latitude, longitude: position.longitude, altitude: position.altitude };
}

placeHtmlBadge: async function (anchorId, text) {
  // Validate everything before touching the badge already placed.
  if (!text || !String(text).trim()) return { status: 'textRequired' };
  var anchor = venue.pois.find(function (p) { return p.id === anchorId; });
  if (!anchor) return { status: 'poiNotFound' };
  // Our own marker is in anchor.markers too: never read the position from it.
  var anchorPosition = anchorPositionOf(anchor, htmlBadge);
  if (!anchorPosition) return { status: 'noPosition' };

  if (htmlBadge) {                       // one badge at a time
    venue.removeMarker(htmlBadge);
    htmlBadge = null;
  }

  // Content styling only -- the SDK owns position/top/left/translate/transform/z-index.
  var element = document.createElement('div');
  element.setAttribute('style',
    'background:#0B6BCB;color:#FFFFFF;font:600 14px sans-serif;padding:6px 12px;' +
    'border-radius:14px;white-space:nowrap;box-shadow:0 2px 6px rgba(0,0,0,.3);cursor:pointer');
  element.textContent = text;

  try {
    htmlBadge = venue.createMarker({
      poi: anchor,
      position: {
        latitude: anchorPosition.latitude + 0.00004,
        longitude: anchorPosition.longitude + 0.00004,
        altitude: anchorPosition.altitude,
      },
      element: element,
    });
  } catch (e) {
    return { status: 'error', message: e.message };
  }

  // createMarker sets pointer-events:none on the element: make it tappable.
  element.style.pointerEvents = 'auto';
  element.addEventListener('click', function (event) {
    event.stopPropagation();   // don't let the tap reach the map underneath
    window.webkit.messageHandlers.mapBridge.postMessage({ type: 'htmlBadgeTapped' });
  });
  return { status: 'placed' };
},

// Content change: a plain DOM edit on the live element, no SDK call.
updateHtmlBadgeText: function (text) {
  if (!htmlBadge) return { status: 'noBadge' };
  if (!text || !String(text).trim()) return { status: 'textRequired' };
  htmlBadge.element.textContent = text;
  return { status: 'updated' };
},

setHtmlBadgeVisible: function (isVisible) {
  if (!htmlBadge) return { status: 'noBadge' };
  venue.updateMarker(htmlBadge, { isVisible: isVisible });
  return { status: 'updated' };
},

removeHtmlBadge: function () {
  if (!htmlBadge) return;   // the SDK throws on a double remove
  venue.removeMarker(htmlBadge);
  htmlBadge = null;
},
```

```swift
// Native -> JS: callAsyncJavaScript with `arguments`, so the text is passed
// safely (no string interpolation); the { status, message? } object comes
// back as a [String: Any].
let placed = await callHtmlBadgeBridge(
    "return await window.MapBridge.placeHtmlBadge(anchorId, text);",
    arguments: ["anchorId": "B4-UL00-ID0009", "text": "Open now \u{00B7} 12:00\u{2013}14:00"]
)
_ = await callHtmlBadgeBridge("return window.MapBridge.updateHtmlBadgeText(text);", arguments: ["text": "Closed today"])
_ = await callHtmlBadgeBridge("return window.MapBridge.setHtmlBadgeVisible(isVisible);", arguments: ["isVisible": false])
webView.callAsyncJavaScript("window.MapBridge.removeHtmlBadge();", arguments: [:], in: nil, in: .page) { _ in }

// JS -> native: the badge's click arrives through the WKScriptMessageHandler
// registered as "mapBridge" (registered via a weak proxy to avoid a retain cycle).
func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
    guard let body = message.body as? [String: Any], let type = body["type"] as? String else { return }
    switch type {
    case "htmlBadgeTapped":
        htmlBadgeTapCount += 1
    default:
        break
    }
}
```

- `venue.createMarker(options: { poi, position, element }): Marker` — creates an HTML marker owned by `poi`, at WGS84 `position` `{ latitude, longitude, altitude? }`, displaying `element`.
- `venue.updateMarker(marker, options: { position?, isVisible? })` — moves or shows/hides it. Nothing else can be updated through it.
- `venue.removeMarker(marker)` — removes the marker and detaches its element from the DOM.
- `marker.element` — the live DOM node you passed in; edit it directly to change the content.

After a successful place, the demo moves the camera to the anchor POI with the same floor switch + `view.goToPOI()` as `docs/features/goto-poi.md`.

## Things to know

- **`element` is required.** Without it, `createMarker` throws `Cannot createMarker, invalid element provided, options.element is missing`.
- **The SDK owns the element's layout.** It moves the element into its own overlay container and sets `position: absolute; top: 0; left: 0; translate: -50% -50%` (the element is **centered** on the position), a per-frame `transform: translate(x, y)` and a `z-index`. Don't set those properties on the element yourself; wrap your content in a child element if you need your own transforms.
- **The element is not tappable by default.** `createMarker` sets `pointer-events: none` on it, so taps fall through to the map and open the POI card of whatever is underneath. Set `element.style.pointerEvents = 'auto'` right after `createMarker` (the SDK doesn't rewrite it later, including after camera moves), and call `event.stopPropagation()` in your click handler so the tap doesn't also reach the map.
- **Drawn above the 3D scene.** The element is never occluded by walls or other geometry and stays readable at any camera pitch. It is still drawn below the SDK's own UI panels (e.g. the POI card).
- **Floor visibility.** The element is only displayed while its POI's floor is the displayed floor; on any other floor the SDK sets `display: none` on it. Move the camera there (see `docs/features/goto-poi.md`) to show it.
- **`updateMarker` only accepts `position` and `isVisible`.** `isVisible: false` sets `display: none` (the element stays in the DOM). Content changes are plain DOM edits on `marker.element`.
- **Double remove / update after remove throws.** Once removed, the marker is no longer registered: `removeMarker` or `updateMarker` on it again throws `Provided marker is not registered`. Drop your reference after removing.
- **The marker belongs to its POI.** After `createMarker`, the anchor's `poi.markers` contains your marker. Skip it when reading the anchor's position again (for a re-place), otherwise an anchor without a label of its own would hand back your marker's already-offset position.
- **POIs have no direct lat/lng field.** The position can only be read from an attached label, marker or image. A surface-only POI (for example `B3-UL00-ID0065` on the shared demo map) has nothing to copy.
- Runtime markers are not persisted: they live in the SDK's in-memory venue model for the current page load only.

## Learn more

- `docs/features/custom-text-label.md` — the 3D-scene counterpart (`venue.createLabel()`): occluded by geometry, not tappable.
- `docs/features/3d-icon-marker.md` — an image in the 3D scene (`venue.createImage()`), same anchor-position lookup.
- `isForeignMarker` and the `foreignmarkerupdated` event — the SDK's variant for positioning **native** views (outside the web page) over the map; not demonstrated here.
