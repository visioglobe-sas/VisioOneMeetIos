# 3D icon marker

## Description

Places a custom image — here a small icon — at a precise spot in the 3D scene via `venue.createImage()`, changes how it's oriented relative to the camera via `venue.updateImage()`, and removes it via `venue.removeImage()`. Typical use: attaching a business visual (a product photo, a promo badge, a brand logo) to a place, beyond the SDK's own default POI icons.

Every `Image` must belong to a POI. This demo uses an existing "anchor" POI (resolved by id) as the owner, and places the image at that POI's own position — its first label's or marker's `.position`, the same lookup `docs/features/dynamic-poi-crud.md` uses. The image itself is a 96×96 PNG passed as a `data:` URL. One image is tracked at a time; placing again replaces it.

## SDK usage

```js
// VisioOneMeet/WebContent/features/3d-icon-marker.js
// iconImages holds the Image objects, keyed by an id chosen by the native
// side -- Image isn't JSON-serializable, so only the key crosses the bridge.
var iconImages = {};

core.register({
  placeIconImage: async function (imageId, anchorId, url, orientationType) {
    var venue = core.venue;
    if (!venue) return { status: 'poiNotFound' };
    var anchor = core.findPoi(anchorId);
    if (!anchor) return { status: 'poiNotFound' };
    var position = core.poiDisplayPosition(anchor, iconImages[imageId]); // skips our own icon; see simulated-position.md
    if (!position) return { status: 'noPosition' };

    if (iconImages[imageId]) {
      venue.removeImage(iconImages[imageId]);
      delete iconImages[imageId];
    }

    try {
      iconImages[imageId] = venue.createImage({
        poi: anchor,
        position: position,       // WGS84 { latitude, longitude, altitude? }
        width: 6,                 // meters
        height: 6,                // meters
        url: url,                 // any image URL, data: URLs included
        orientationType: orientationType, // 'fixed' | 'flat' | 'facing'
      });
    } catch (e) {
      return { status: 'error', message: core.errorMessage(e) };
    }
    return { status: 'placed', id: imageId };
  },
  updateIconImageOrientation: function (imageId, orientationType) {
    if (!core.venue || !iconImages[imageId]) return;
    core.venue.updateImage(iconImages[imageId], { orientationType: orientationType });
  },
  removeIconImage: function (imageId) {
    if (!core.venue || !iconImages[imageId]) return;
    core.venue.removeImage(iconImages[imageId]);
    delete iconImages[imageId];
  },
});
```

```swift
// VisioOneMeet/Features/3dIconMarker/IconMarker3D+Bridge.swift
enum IconOrientation: String, CaseIterable, Identifiable {
    case fixed, flat, facing   // raw values = the SDK's OrientationType strings
    var id: String { rawValue }
}

extension VisioOneBridge {
    /// { status: 'placed' | 'poiNotFound' | 'noPosition' | 'error', message? },
    /// mapped to a BridgeResult (.success, .poiNotFound, .noPosition, .sdkError).
    func placeIconImage(imageId: String, anchorId: String, url: String, orientation: IconOrientation) async -> BridgeResult {
        await callForStatus("placeIconImage", args: [imageId, anchorId, url, orientation.rawValue])
    }

    func updateIconImageOrientation(imageId: String, orientation: IconOrientation) {
        call("updateIconImageOrientation", args: [imageId, orientation.rawValue])
    }

    func removeIconImage(imageId: String) {
        call("removeIconImage", args: [imageId])
    }
}

// VisioOneMeet/Features/3dIconMarker/IconMarker3DModel.swift
func place(anchorId: String) async -> BridgeResult {
    let result = await bridge.placeIconImage(
        imageId: Self.iconImageId,      // "3d-icon-marker"
        anchorId: anchorId,
        url: Self.iconDataURL,          // "data:image/png;base64,..."
        orientation: orientation
    )
    if result == .success {
        placedAnchorId = anchorId
    }
    return result
}
```

- `venue.createImage(options: { poi, position, width, height?, rotation?, url, orientationType? }): Image` — creates an image attached to `poi`. `width`/`height` are in meters; `position` is WGS84.
- `venue.updateImage(image, options: { orientationType?, width?, position?, rotation?, url?, isVisible? })` — edits an existing image in place; changing `orientationType` takes effect immediately, no re-creation needed.
- `venue.removeImage(image)` — removes that image only; the owning POI and its other visual elements are untouched.
- `OrientationType`: `'fixed'` lies flat on the ground with a fixed heading (`rotation`); `'flat'` lies flat on the ground but turns to face the camera; `'facing'` is a billboard that always faces the camera.

The bridge helpers pass the data URL and ids as `callAsyncJavaScript` arguments (rather than interpolating them into a script string), which keeps arbitrary strings safe to send across the bridge.

## Things to know

- **A `data:` URL works as `url`.** A base64 PNG renders exactly like a remote image, which avoids any network/CORS concern for small, app-bundled icons.
- **`createImage` throws synchronously on an invalid `orientationType`** (`"Invalid orientation type"`) — only the three literal strings are accepted. The JS side above wraps the call in `try/catch` so it comes back as a normal `{ status: 'error' }` outcome.
- **`'flat'`/`'facing'` on runtime-created images require SDK ≥ 1.0.9.** In 1.0.5, an image created with `createImage`, or switched with `updateImage`, to `'flat'` or `'facing'` lay flat on the ground and never turned with the camera. This was an SDK bug, fixed in 1.0.9. `'fixed'` works on both versions.
- **The owning POI keeps its own visuals.** An anchor POI that already has an SDK icon keeps it: after `createImage`, `poi.images` holds both. `removeImage` only removes the one you pass.
- **POIs have no direct lat/lng field.** The position is read off what is attached to the POI: first label, else first image, else first marker, else the centroid of its first surface (see `docs/features/simulated-position.md`). A surface-only POI (for example `B3-UL00-ID0065` on the shared demo map) therefore resolves to the middle of its surface.
- **Images follow their floor's visibility.** An image placed on an indoor floor is not drawn in the global (outside) view, like everything else on that floor. Move the camera to that floor (for example with `view.goToFloor()` + `view.goToPOI()`, see `docs/features/goto-poi.md`) to show it.
- Runtime images are not persisted: they live in the SDK's in-memory venue model for the current page load only.

## Learn more

- `docs/features/dynamic-poi-crud.md` — creating runtime POIs and labels using the same anchor-position lookup.
- `docs/features/goto-poi.md` — the floor switch + camera move this demo runs after placing the icon.
