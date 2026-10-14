# Custom text label

## Description

Places your own free text on the map — opening hours, a price, a zone name — via `venue.createLabel()`, restyles it live (text, color, size) via `venue.updateLabel()`, and removes it via `venue.removeLabel()`. The label is independent of the map's own labels: it is added next to them, never replaces them.

Every `Label` must belong to a POI. This demo uses an existing "anchor" POI (resolved by id, `B4-UL00-ID0009` "Restaurant" by default) as the owner, reads that POI's position from its first label or marker (the same lookup as `docs/features/dynamic-poi-crud.md` and `docs/features/3d-icon-marker.md`), and offsets it by `+0.00004` in latitude and longitude (about 4 m) so the custom text doesn't overlap the POI's own "Restaurant" label. One custom label is tracked at a time. Placing again validates everything first (text, anchor POI, anchor position) and only then replaces the previous label, so a failed place leaves the existing one untouched and still editable.

## SDK usage

```js
// window.MapBridge, JS side. textLabel holds the Label object -- Label isn't
// JSON-serializable, so it never crosses the bridge. textLabelOptions keeps
// the createLabel options so a rotation change can recreate it.
var textLabel = null;
var textLabelOptions = null;

function createTextLabel(options) {
  try {
    textLabel = venue.createLabel(options);
  } catch (e) {
    return { status: 'error', message: e && e.message ? e.message : String(e) };
  }
  textLabelOptions = options;
  return { status: 'placed' };
}

// First label's, else first marker's .position -- skipping `exclude` (one of our own overlays).
function anchorPositionOf(poi, exclude) {
  var label = (poi.labels || []).find(function (l) { return l !== exclude; });
  var marker = (poi.markers || []).find(function (m) { return m !== exclude; });
  var position = (label && label.position) || (marker && marker.position);
  if (!position) return null;
  return { latitude: position.latitude, longitude: position.longitude, altitude: position.altitude };
}

placeTextLabel: async function (anchorId, text, color, width, height, rotation) {
  // Validate everything before touching the label already placed.
  if (!text || !String(text).trim()) return { status: 'textRequired' };
  var anchor = venue.pois.find(function (p) { return p.id === anchorId; });
  if (!anchor) return { status: 'poiNotFound' };
  // Our own label is attached to the anchor too: never read the position from it.
  var anchorPosition = anchorPositionOf(anchor, textLabel);
  if (!anchorPosition) return { status: 'noPosition' };

  if (textLabel) {                       // one label at a time
    venue.removeLabel(textLabel);
    textLabel = null;
  }

  return createTextLabel({
    poi: anchor,
    position: {
      latitude: anchorPosition.latitude + 0.00004,
      longitude: anchorPosition.longitude + 0.00004,
      altitude: anchorPosition.altitude,
    },
    width: width,       // meters
    height: height,     // meters -- always pass it, see "Things to know"
    text: text,
    color: color,       // '#E53935', 'rgb(...)' or 'hsl(...)'
    rotation: rotation, // degrees, creation only
  });
},

// options: { text } or { color } or { width, height } -- never rotation
updateTextLabel: function (options) {
  if (!textLabel) return { status: 'noLabel' };
  if ('text' in options && (!options.text || !String(options.text).trim())) {
    return { status: 'textRequired' };
  }
  try {
    venue.updateLabel(textLabel, options);
  } catch (e) {
    return { status: 'error', message: e.message };
  }
  Object.assign(textLabelOptions, options);
  return { status: 'updated' };
},

// rotation isn't part of LabelUpdateOptions: remove + recreate
setTextLabelRotation: function (rotation) {
  if (!textLabel) return { status: 'noLabel' };
  var options = Object.assign({}, textLabelOptions, { rotation: rotation });
  venue.removeLabel(textLabel);
  textLabel = null;
  return createTextLabel(options);
},

removeTextLabel: function () {
  if (!textLabel) return;   // the SDK throws on a double remove
  venue.removeLabel(textLabel);
  textLabel = null;
},
```

```swift
// Native side: every call goes through callAsyncJavaScript with `arguments`,
// so the text and color strings are passed safely (no string interpolation),
// and the { status, message? } object comes back as a [String: Any].
func placeTextLabel(anchorId: String, text: String) async -> TextLabelResult {
    await callTextLabelBridge(
        "return await window.MapBridge.placeTextLabel(anchorId, text, color, width, height, rotation);",
        arguments: [
            "anchorId": anchorId,
            "text": text,
            "color": "#E53935",
            "width": 16.0,
            "height": 3.0,
            "rotation": 0,
        ]
    )
}

// Live restyle -- width and height are always sent together.
callTextLabelBridge("return window.MapBridge.updateTextLabel({ text: text });", arguments: ["text": text])
callTextLabelBridge("return window.MapBridge.updateTextLabel({ color: color });", arguments: ["color": "#43A047"])
callTextLabelBridge("return window.MapBridge.updateTextLabel({ width: width, height: height });",
                    arguments: ["width": 22.0, "height": 4.0])
callTextLabelBridge("return window.MapBridge.setTextLabelRotation(rotation);", arguments: ["rotation": 90])

webView.callAsyncJavaScript("window.MapBridge.removeTextLabel();", arguments: [:], in: nil, in: .page) { _ in }

private func callTextLabelBridge(_ script: String, arguments: [String: Any]) async -> TextLabelResult {
    await withCheckedContinuation { continuation in
        webView.callAsyncJavaScript(script, arguments: arguments, in: nil, in: .page) { result in
            // maps { status: 'placed' | 'updated' | 'textRequired' | 'poiNotFound'
            //        | 'noPosition' | 'noLabel' | 'error', message? } into TextLabelResult
        }
    }
}
```

- `venue.createLabel(options: { poi, position, width, height?, text, color?, rotation? }): Label` — creates a text label owned by `poi`. `width`/`height` are the text box size in meters; `position` is WGS84 `{ latitude, longitude, altitude? }`; `rotation` is in degrees.
- `venue.updateLabel(label, options: { text?, color?, width?, height?, ... })` — edits an existing label in place (`LabelUpdateOptions`). `rotation` is not part of it.
- `venue.removeLabel(label)` — removes that label only; the owning POI and its other labels are untouched.

After a successful place, the demo moves the camera to the anchor POI with the same floor switch + `view.goToPOI()` as `docs/features/goto-poi.md`.

## Things to know

- **Always pass `height` explicitly.** On `createLabel`, `height` is optional and defaults to `width`: you get a square box and the text is fitted into it, so it wraps or gets huge.
- **Always update `width` and `height` together.** `updateLabel(label, { width })` alone also sets `height = width` (documented in `LabelUpdateOptions`), which garbles the text the same way.
- **`rotation` can only be set at creation.** It is part of `LabelCreateOptions`, not `LabelUpdateOptions`. To change it, remove the label and create it again with the new rotation. Passing `rotation` to `updateLabel` anyway was observed (SDK 1.0.9) to rotate the rendering while `label.rotation` keeps the old value; this is undocumented, so don't rely on it.
- **`color` must be hex, `rgb()` or `hsl()`.** Alpha is ignored. Anything else (a CSS color name, for example) makes the call throw `Invalid color format provided…`.
- **Empty text throws.** `createLabel` with an empty `text` throws `Cannot create Label, text is required`. Validate before calling (the JS side above trims and returns `textRequired`).
- **Double remove / update after remove throws.** Once removed, the `Label` object is no longer registered: `removeLabel` or `updateLabel` on it again throws `Provided label is not registered`. Drop your reference after removing.
- **The label belongs to its POI.** After `createLabel`, the anchor's `poi.labels` holds both the map's own label and yours; the map's own label is not altered. `removeLabel` only removes the one you pass. Because your label is now in `poi.labels`, skip it when reading the anchor's position again (for a re-place), otherwise an anchor without a label of its own would hand back your label's already-offset position.
- **Text is fitted inside `width` × `height`.** Long text wraps to two lines rather than overflowing the box.
- **Labels follow their floor's visibility.** A label owned by a POI on an indoor floor is only drawn when that floor is displayed, so move the camera there (see `docs/features/goto-poi.md`) to show it.
- **POIs have no direct lat/lng field.** The position can only be read from an attached label, marker or image. A surface-only POI (for example `B3-UL00-ID0065` on the shared demo map) has nothing to copy.
- Runtime labels are not persisted: they live in the SDK's in-memory venue model for the current page load only.

## Learn more

- `docs/features/dynamic-poi-crud.md` — creating a brand-new POI and attaching a label to it.
- `docs/features/3d-icon-marker.md` — the image counterpart of this feature (`venue.createImage()`), same anchor-position lookup.
- `docs/features/goto-poi.md` — the floor switch + camera move run after placing the label.
