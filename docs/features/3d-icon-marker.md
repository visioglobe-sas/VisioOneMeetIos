# 3D icon marker

## Description

Places a custom image — here a small icon — at a precise spot in the 3D scene via `venue.createImage()`, changes how it's oriented relative to the camera via `venue.updateImage()`, and removes it via `venue.removeImage()`. Typical use: attaching a business visual (a product photo, a promo badge, a brand logo) to a place, beyond the SDK's own default POI icons.

Every `Image` must belong to a POI. This demo uses an existing "anchor" POI (resolved by id) as the owner, and places the image at that POI's own position — its first label's or marker's `.position`, the same lookup `docs/features/dynamic-poi-crud.md` uses. The image itself is a 96×96 PNG passed as a `data:` URL. One image is tracked at a time; placing again replaces it.

## SDK usage

```js
// window.MapBridge, JS side. iconImages holds the Image objects, keyed by an
// id chosen by the native side -- Image isn't JSON-serializable, so only the
// key crosses the bridge.
placeIconImage: async function (imageId, anchorId, url, orientationType) {
  if (!venue) return { status: 'poiNotFound' };
  var anchor = venue.pois.find(function (p) { return p.id === anchorId; });
  if (!anchor) return { status: 'poiNotFound' };
  var position = anchorPositionOf(anchor); // first label's, else first marker's .position
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
    return { status: 'error', message: e && e.message ? e.message : String(e) };
  }
  return { status: 'placed', id: imageId };
},
updateIconImageOrientation: function (imageId, orientationType) {
  if (!venue || !iconImages[imageId]) return;
  venue.updateImage(iconImages[imageId], { orientationType: orientationType });
},
removeIconImage: function (imageId) {
  if (!venue || !iconImages[imageId]) return;
  venue.removeImage(iconImages[imageId]);
  delete iconImages[imageId];
},
```

```swift
enum IconOrientation: String, CaseIterable {
    case fixed, flat, facing   // raw values = the SDK's OrientationType strings
}

func placeIcon(anchorId: String) async -> PlaceIconResult {
    guard let webView else { return .failure("Map not ready") }
    return await withCheckedContinuation { continuation in
        webView.callAsyncJavaScript(
            "return await window.MapBridge.placeIconImage(imageId, anchorId, url, orientationType);",
            arguments: [
                "imageId": "3d-icon-marker",
                "anchorId": anchorId,
                "url": Self.iconDataURL,          // "data:image/png;base64,..."
                "orientationType": iconOrientation.rawValue,
            ],
            in: nil,
            in: .page
        ) { result in
            // ... maps { status: 'placed' | 'poiNotFound' | 'noPosition' | 'error', message? }
            // into PlaceIconResult
        }
    }
}

func setIconOrientation(_ orientation: IconOrientation) {
    webView?.callAsyncJavaScript(
        "window.MapBridge.updateIconImageOrientation(imageId, orientationType);",
        arguments: ["imageId": "3d-icon-marker", "orientationType": orientation.rawValue],
        in: nil, in: .page
    ) { _ in }
}

func removeIcon() {
    webView?.callAsyncJavaScript(
        "window.MapBridge.removeIconImage(imageId);",
        arguments: ["imageId": "3d-icon-marker"],
        in: nil, in: .page
    ) { _ in }
}
```

- `venue.createImage(options: { poi, position, width, height?, rotation?, url, orientationType? }): Image` — creates an image attached to `poi`. `width`/`height` are in meters; `position` is WGS84.
- `venue.updateImage(image, options: { orientationType?, width?, position?, rotation?, url?, isVisible? })` — edits an existing image in place; changing `orientationType` takes effect immediately, no re-creation needed.
- `venue.removeImage(image)` — removes that image only; the owning POI and its other visual elements are untouched.
- `OrientationType`: `'fixed'` lies flat on the ground with a fixed heading (`rotation`); `'flat'` lies flat on the ground but turns to face the camera; `'facing'` is a billboard that always faces the camera.

Passing the data URL and ids through `callAsyncJavaScript`'s `arguments` (rather than interpolating them into a script string) keeps arbitrary strings safe to send across the bridge.

## Things to know

- **A `data:` URL works as `url`.** A base64 PNG renders exactly like a remote image, which avoids any network/CORS concern for small, app-bundled icons.
- **`createImage` throws synchronously on an invalid `orientationType`** (`"Invalid orientation type"`) — only the three literal strings are accepted. The JS side above wraps the call in `try/catch` so it comes back as a normal `{ status: 'error' }` outcome.
- **SDK bug in `@visioglobe/visioone` 1.0.x: runtime `'flat'`/`'facing'` images do not follow the camera.** An image created with `createImage`, or switched with `updateImage`, to `'flat'` or `'facing'` lies flat on the ground and never turns with the camera, as if no orientation were applied. The map's own `'facing'` icons do stand upright, even though their public `Image` objects look the same (`orientationType: 'facing'`). The cause is inside the SDK. `'flat'`/`'facing'` rely on a per-frame update (`ConstrainedCameraFacing.update()`) that only runs for images registered in the SDK's "updatables" loop. Images loaded with the map are registered (`ImageAdapter.endAdapt(true)` calls `registerUpdatables()`). Runtime images go through `ImageAdapter.endAdapt()` with its default `false`, which skips that registration, so their transform stays at identity. No public API call registers them. On this demo, at the anchor label's own altitude, `'flat'`/`'facing'` images z-fight with the floor, surface and label: half a disc shows from a top-down camera, and nothing shows from a low camera angle. `'fixed'` is not affected and stays visible at every pitch. Raising `position.altitude` by a few meters removes the z-fighting, but the image still lies flat. This demo keeps the anchor's position unchanged, so you can see the bug when you switch orientation.
- **The owning POI keeps its own visuals.** An anchor POI that already has an SDK icon keeps it: after `createImage`, `poi.images` holds both. `removeImage` only removes the one you pass.
- **POIs have no direct lat/lng field.** A position can only be read from an attached label, marker or image. A POI that only has a surface (for example `B3-UL00-ID0065` on the shared demo map, while `B4-UL00-ID0009` "Restaurant" has a label) has nothing to copy, and this demo reports "This POI has no position" for it.
- **Images follow their floor's visibility.** An image placed on an indoor floor is not drawn in the global (outside) view, like everything else on that floor. Move the camera to that floor (for example with `view.goToFloor()` + `view.goToPOI()`, see `docs/features/goto-poi.md`) to show it.
- Runtime images are not persisted: they live in the SDK's in-memory venue model for the current page load only.

## Learn more

- `docs/features/dynamic-poi-crud.md` — creating runtime POIs and labels using the same anchor-position lookup.
- `docs/features/goto-poi.md` — the floor switch + camera move this demo runs after placing the icon.
