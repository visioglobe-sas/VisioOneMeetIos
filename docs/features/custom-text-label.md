# Custom text label

## Description

Places your own free text on the map — opening hours, a price, a zone name — via `venue.createLabel()`, restyles it live (text, color, size) via `venue.updateLabel()`, and removes it via `venue.removeLabel()`. The label is independent of the map's own labels: it is added next to them, never replaces them.

Every `Label` must belong to a POI. This demo uses an existing "anchor" POI (resolved by id, `B4-UL00-ID0009` "Restaurant" by default) as the owner, reads that POI's display position (first label, else image, else marker, else surface centroid; the same lookup as `docs/features/dynamic-poi-crud.md` and `docs/features/3d-icon-marker.md`), and offsets it by `+0.00004` in latitude and longitude (about 4 m) so the custom text doesn't overlap the POI's own "Restaurant" label. One custom label is tracked at a time. Placing again validates everything first (text, anchor POI, anchor position) and only then replaces the previous label, so a failed place leaves the existing one untouched and still editable.

## SDK usage

```js
// VisioOneMeet/WebContent/features/custom-text-label.js
// textLabel holds the Label object -- Label isn't JSON-serializable, so it
// never crosses the bridge. textLabelOptions keeps the createLabel options so
// a rotation change can recreate it.
var textLabel = null;
var textLabelOptions = null;

function createTextLabel(options) {
  try {
    textLabel = core.venue.createLabel(options);
  } catch (e) {
    return { status: 'error', message: core.errorMessage(e) };
  }
  textLabelOptions = options;
  return { status: 'placed' };
}

function removeCurrentLabel() {
  core.venue.removeLabel(textLabel);
  textLabel = null;
  textLabelOptions = null;
}

core.register({
  placeTextLabel: async function (anchorId, text, color, width, height, rotation) {
    if (!core.venue) return { status: 'poiNotFound' };
    // Validate everything before touching the label already placed.
    if (!text || !String(text).trim()) return { status: 'textRequired' };
    var anchor = core.findPoi(anchorId);
    if (!anchor) return { status: 'poiNotFound' };
    // Our own label is attached to the anchor too: never read the position from it.
    var anchorPosition = core.poiDisplayPosition(anchor, textLabel);
    if (!anchorPosition) return { status: 'noPosition' };

    if (textLabel) removeCurrentLabel(); // one label at a time

    return createTextLabel({
      poi: anchor,
      position: core.offsetPosition(anchorPosition), // ~4 m north-east of the anchor
      width: width,       // meters
      height: height,     // meters -- always pass it, see "Things to know"
      text: text,
      color: color,       // '#E53935', 'rgb(...)' or 'hsl(...)'
      rotation: rotation, // degrees, creation only
    });
  },

  // options: { text } or { color } or { width, height } -- never rotation
  updateTextLabel: function (options) {
    if (!core.venue || !textLabel) return { status: 'noLabel' };
    if ('text' in options && (!options.text || !String(options.text).trim())) {
      return { status: 'textRequired' };
    }
    try {
      core.venue.updateLabel(textLabel, options);
    } catch (e) {
      return { status: 'error', message: core.errorMessage(e) };
    }
    Object.assign(textLabelOptions, options);
    return { status: 'updated' };
  },

  // rotation isn't part of LabelUpdateOptions: remove + recreate
  setTextLabelRotation: function (rotation) {
    if (!core.venue || !textLabel) return { status: 'noLabel' };
    var options = Object.assign({}, textLabelOptions, { rotation: rotation });
    removeCurrentLabel();
    return createTextLabel(options);
  },

  removeTextLabel: function () {
    if (!core.venue || !textLabel) return; // the SDK throws on a double remove
    removeCurrentLabel();
  },
});
```

`core.poiDisplayPosition` and `core.offsetPosition` live in `VisioOneMeet/WebContent/bridge/core.js` (the POI position rule is described in `docs/features/simulated-position.md`).

```swift
// VisioOneMeet/Features/CustomTextLabel/CustomTextLabel+Bridge.swift
// callForStatus passes the arguments as real JS values (no string
// interpolation) and maps the { status, message? } object to a BridgeResult.
extension VisioOneBridge {
    func placeTextLabel(anchorId: String, text: String, color: TextLabelColor, size: TextLabelSize, rotation: Int) async -> BridgeResult {
        await callForStatus("placeTextLabel", args: [anchorId, text, color.rawValue, size.width, size.height, rotation])
    }

    // Live restyle: ["text": ...], ["color": ...] or ["width": ..., "height": ...] -- width and height always together.
    func updateTextLabel(_ options: [String: Any]) async -> BridgeResult {
        await callForStatus("updateTextLabel", args: [options])
    }

    func setTextLabelRotation(_ rotation: Int) async -> BridgeResult {
        await callForStatus("setTextLabelRotation", args: [rotation])
    }

    func removeTextLabel() {
        call("removeTextLabel")
    }
}
```

```swift
// VisioOneMeet/Features/CustomTextLabel/CustomTextLabelModel.swift
func place(anchorId: String) async -> BridgeResult {
    let text = text
    let result = await bridge.placeTextLabel(anchorId: anchorId, text: text, color: color, size: size, rotation: rotation)
    switch result {
    case .success:
        placedAnchorId = anchorId
        placedText = text
    case .sdkError:
        // Validation passed and the previous label was already removed,
        // but venue.createLabel itself threw: nothing is placed anymore.
        clearPlaced()
    default:
        // Validation failed before anything was touched, or the bridge call
        // itself failed (map state unknown): keep the native state.
        break
    }
    return result
}
```

- `venue.createLabel(options: { poi, position, width, height?, text, color?, rotation? }): Label` — creates a text label owned by `poi`. `width`/`height` are the text box size in meters; `position` is WGS84 `{ latitude, longitude, altitude? }`; `rotation` is in degrees.
- `venue.updateLabel(label, options: { text?, color?, width?, height?, ... })` — edits an existing label in place (`LabelUpdateOptions`). `rotation` is not part of it.
- `venue.removeLabel(label)` — removes that label only; the owning POI and its other labels are untouched.

After a successful place, the demo moves the camera to the anchor POI with the same floor switch + `view.goToPOI()` as `docs/features/goto-poi.md`.

## Things to know

- **Only forget the placed label when the SDK says it is gone.** A re-place removes the previous label and then calls `venue.createLabel`: if that SDK call throws (`{ status: 'error' }`), nothing is placed anymore. But a failure of the bridge call itself (WebKit error, unexpected response) says nothing about the map, so keep your native state as it was in that case.
- **Always pass `height` explicitly.** On `createLabel`, `height` is optional and defaults to `width`: you get a square box and the text is fitted into it, so it wraps or gets huge.
- **Always update `width` and `height` together.** `updateLabel(label, { width })` alone also sets `height = width` (documented in `LabelUpdateOptions`), which garbles the text the same way.
- **`rotation` can only be set at creation.** It is part of `LabelCreateOptions`, not `LabelUpdateOptions`. To change it, remove the label and create it again with the new rotation. Passing `rotation` to `updateLabel` anyway was observed (SDK 1.0.9) to rotate the rendering while `label.rotation` keeps the old value; this is undocumented, so don't rely on it.
- **`color` must be hex, `rgb()` or `hsl()`.** Alpha is ignored. Anything else (a CSS color name, for example) makes the call throw `Invalid color format provided…`.
- **Empty text throws.** `createLabel` with an empty `text` throws `Cannot create Label, text is required`. Validate before calling (the JS side above trims and returns `textRequired`).
- **Double remove / update after remove throws.** Once removed, the `Label` object is no longer registered: `removeLabel` or `updateLabel` on it again throws `Provided label is not registered`. Drop your reference after removing.
- **The label belongs to its POI.** After `createLabel`, the anchor's `poi.labels` holds both the map's own label and yours; the map's own label is not altered. `removeLabel` only removes the one you pass. Because your label is now in `poi.labels`, skip it when reading the anchor's position again (for a re-place), otherwise an anchor without a label of its own would hand back your label's already-offset position.
- **Text is fitted inside `width` × `height`.** Long text wraps to two lines rather than overflowing the box.
- **Labels follow their floor's visibility.** A label owned by a POI on an indoor floor is only drawn when that floor is displayed, so move the camera there (see `docs/features/goto-poi.md`) to show it.
- **POIs have no direct lat/lng field.** The position is read off what is attached to the POI: first label, else first image, else first marker, else the centroid of its first surface (see `docs/features/simulated-position.md`). A surface-only POI (for example `B3-UL00-ID0065` on the shared demo map) therefore resolves to the middle of its surface.
- Runtime labels are not persisted: they live in the SDK's in-memory venue model for the current page load only.

## Learn more

- `docs/features/dynamic-poi-crud.md` — creating a brand-new POI and attaching a label to it.
- `docs/features/3d-icon-marker.md` — the image counterpart of this feature (`venue.createImage()`), same anchor-position lookup.
- `docs/features/goto-poi.md` — the floor switch + camera move run after placing the label.
