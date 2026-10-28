# HTML overlay marker

## Description

Pins an HTML element — here a small "Open now · 12:00–14:00" badge — on the map at a geographic position via `venue.createMarker({ poi, position, element })`. Unlike a `Label` or an `Image`, which live inside the 3D scene, a marker's element is a regular DOM node drawn on top of the map: it always faces the screen, is never hidden by walls or other 3D geometry, and — the point of this demo — it is **interactive**: tapping it reaches the app. The text is changed with a plain DOM edit, the badge is shown/hidden via `venue.updateMarker(marker, { isVisible })`, and removed via `venue.removeMarker(marker)`.

Every marker must belong to a POI. This demo uses an existing "anchor" POI (resolved by id, `B4-UL00-ID0009` "Restaurant" by default) as the owner, reads that POI's display position (first label, else image, else marker, else surface centroid; the same lookup as `docs/features/dynamic-poi-crud.md`, `docs/features/3d-icon-marker.md` and `docs/features/custom-text-label.md`), and offsets it by `+0.00004` in latitude and longitude (about 4 m). One badge is tracked at a time. Placing again validates everything first (text, anchor POI, anchor position) and only then replaces the previous badge, so a failed place leaves the existing one untouched.

In this iOS app the element is created by the JS side inside the `WKWebView`; its `click` is forwarded to Swift through the `WKScriptMessageHandler` bridge, where the tap is counted.

## SDK usage

```js
// VisioOneMeet/WebContent/features/html-overlay-marker.js
// htmlBadge holds the Marker -- not JSON-serializable, so it never crosses
// the bridge.
var htmlBadge = null;
var HTML_BADGE_STYLE =
  'background:#0B6BCB;color:#FFFFFF;font:600 14px sans-serif;padding:6px 12px;' +
  'border-radius:14px;white-space:nowrap;box-shadow:0 2px 6px rgba(0,0,0,.3);cursor:pointer';

core.register({
  placeHtmlBadge: async function (anchorId, text) {
    var venue = core.venue;
    if (!venue) return { status: 'poiNotFound' };
    // Validate everything before touching the badge already placed.
    if (!text || !String(text).trim()) return { status: 'textRequired' };
    var anchor = core.findPoi(anchorId);
    if (!anchor) return { status: 'poiNotFound' };
    // Our own marker is in anchor.markers too: never read the position from it.
    var anchorPosition = core.poiDisplayPosition(anchor, htmlBadge);
    if (!anchorPosition) return { status: 'noPosition' };

    if (htmlBadge) {                       // one badge at a time
      venue.removeMarker(htmlBadge);
      htmlBadge = null;
    }

    // Content styling only -- the SDK owns position/top/left/translate/transform/z-index.
    var element = document.createElement('div');
    element.setAttribute('style', HTML_BADGE_STYLE);
    element.textContent = text;

    try {
      htmlBadge = venue.createMarker({
        poi: anchor,
        position: core.offsetPosition(anchorPosition), // ~4 m north-east of the anchor
        element: element,
      });
    } catch (e) {
      return { status: 'error', message: core.errorMessage(e) };
    }

    // createMarker sets pointer-events:none on the element: make it tappable.
    element.style.pointerEvents = 'auto';
    element.addEventListener('click', function (event) {
      event.stopPropagation();   // don't let the tap reach the map underneath
      core.sendToNative('htmlBadgeTapped');
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
    if (!core.venue || !htmlBadge) return { status: 'noBadge' };
    core.venue.updateMarker(htmlBadge, { isVisible: isVisible });
    return { status: 'updated' };
  },

  removeHtmlBadge: function () {
    if (!core.venue || !htmlBadge) return;   // the SDK throws on a double remove
    core.venue.removeMarker(htmlBadge);
    htmlBadge = null;
  },
});
```

`core.poiDisplayPosition` and `core.offsetPosition` live in `VisioOneMeet/WebContent/bridge/core.js` (the POI position rule is described in `docs/features/simulated-position.md`).

```swift
// VisioOneMeet/Features/HtmlOverlayMarker/HtmlOverlayMarker+Bridge.swift
// Native -> JS: callForStatus passes the text as a real JS value (no string
// interpolation) and maps the { status, message? } object to a BridgeResult.
extension VisioOneBridge {
    func placeHtmlBadge(anchorId: String, text: String) async -> BridgeResult {
        await callForStatus("placeHtmlBadge", args: [anchorId, text])
    }

    func updateHtmlBadgeText(_ text: String) async -> BridgeResult {
        await callForStatus("updateHtmlBadgeText", args: [text])
    }

    func setHtmlBadgeVisible(_ isVisible: Bool) async -> BridgeResult {
        await callForStatus("setHtmlBadgeVisible", args: [isVisible])
    }

    func removeHtmlBadge() {
        call("removeHtmlBadge")
    }
}
```

```swift
// VisioOneMeet/Features/HtmlOverlayMarker/HtmlOverlayMarkerModel.swift
// JS -> native: the badge's click arrives through the bridge's
// WKScriptMessageHandler ("mapBridge", registered via a weak proxy to avoid a
// retain cycle), dispatched to the handlers registered for its type.
bridge.onMessage("htmlBadgeTapped") { [weak self] _ in
    self?.tapCount += 1
}
```

- `venue.createMarker(options: { poi, position, element }): Marker` — creates an HTML marker owned by `poi`, at WGS84 `position` `{ latitude, longitude, altitude? }`, displaying `element`.
- `venue.updateMarker(marker, options: { position?, isVisible? })` — moves or shows/hides it. Nothing else can be updated through it.
- `venue.removeMarker(marker)` — removes the marker and detaches its element from the DOM.
- `marker.element` — the live DOM node you passed in; edit it directly to change the content.

After a successful place, the demo moves the camera to the anchor POI with the same floor switch + `view.goToPOI()` as `docs/features/goto-poi.md`.

## Things to know

- **Only forget the placed badge when the SDK says it is gone.** A re-place removes the previous badge and then calls `venue.createMarker`: if that SDK call throws (`{ status: 'error' }`), nothing is placed anymore. But a failure of the bridge call itself (WebKit error, unexpected response) says nothing about the map, so keep your native state as it was in that case.
- **`element` is required.** Without it, `createMarker` throws `Cannot createMarker, invalid element provided, options.element is missing`.
- **The SDK owns the element's layout.** It moves the element into its own overlay container and sets `position: absolute; top: 0; left: 0; translate: -50% -50%` (the element is **centered** on the position), a per-frame `transform: translate(x, y)` and a `z-index`. Don't set those properties on the element yourself; wrap your content in a child element if you need your own transforms.
- **The element is not tappable by default.** `createMarker` sets `pointer-events: none` on it, so taps fall through to the map and open the POI card of whatever is underneath. Set `element.style.pointerEvents = 'auto'` right after `createMarker` (the SDK doesn't rewrite it later, including after camera moves), and call `event.stopPropagation()` in your click handler so the tap doesn't also reach the map.
- **Drawn above the 3D scene.** The element is never occluded by walls or other geometry and stays readable at any camera pitch. It is still drawn below the SDK's own UI panels (e.g. the POI card).
- **Floor visibility.** The element is only displayed while its POI's floor is the displayed floor; on any other floor the SDK sets `display: none` on it. Move the camera there (see `docs/features/goto-poi.md`) to show it.
- **`updateMarker` only accepts `position` and `isVisible`.** `isVisible: false` sets `display: none` (the element stays in the DOM). Content changes are plain DOM edits on `marker.element`.
- **Double remove / update after remove throws.** Once removed, the marker is no longer registered: `removeMarker` or `updateMarker` on it again throws `Provided marker is not registered`. Drop your reference after removing.
- **The marker belongs to its POI.** After `createMarker`, the anchor's `poi.markers` contains your marker. Skip it when reading the anchor's position again (for a re-place), otherwise an anchor without a label of its own would hand back your marker's already-offset position.
- **POIs have no direct lat/lng field.** The position is read off what is attached to the POI: first label, else first image, else first marker, else the centroid of its first surface (see `docs/features/simulated-position.md`). A surface-only POI (for example `B3-UL00-ID0065` on the shared demo map) therefore resolves to the middle of its surface.
- Runtime markers are not persisted: they live in the SDK's in-memory venue model for the current page load only.

## Learn more

- `docs/features/custom-text-label.md` — the 3D-scene counterpart (`venue.createLabel()`): occluded by geometry, not tappable.
- `docs/features/3d-icon-marker.md` — an image in the 3D scene (`venue.createImage()`), same anchor-position lookup.
- `isForeignMarker` and the `foreignmarkerupdated` event — the SDK's variant for positioning **native** views (outside the web page) over the map; not demonstrated here.
