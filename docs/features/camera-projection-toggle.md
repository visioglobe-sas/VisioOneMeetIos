# Camera projection

## Description

Switches the map between the SDK's default 3D **perspective** projection and a flat **orthographic** projection (parallel lines stay parallel, no vanishing point, so it looks like a plan view), via the `cameraProjection` option of `visioOne.createView()`.

`cameraProjection` is a **view-creation option only**: `view.cameraProjection` is read-only and there is no setter, so the projection can't be changed on a live view. Switching it means creating a new view, which in practice means reloading the map. On this app, that means reloading the `WKWebView` page with a different query item. The page's normal startup then runs a fresh `loadVenue` + `createView`.

## SDK usage

```js
// map.html, page init. The projection comes in as a query item set by the
// native side, and is passed to createView. ('perspective' is the default.)
var cameraProjection = new URLSearchParams(window.location.search).get('cameraProjection');

var viewOptions = {};
if (cameraProjection === 'orthographic' || cameraProjection === 'perspective') {
  viewOptions.cameraProjection = cameraProjection;
}

visioOne.loadVenue({ vg_maphash: hash }, container)
  .then(function (v) {
    venue = v;
    return visioOne.createView(container, venue, viewOptions);
  })
  .then(function (v) {
    view = v;
    // ...register every view listener (poiclick, currentfloorchanged, ...)...

    // view.cameraProjection is read-only: it reports the projection the
    // view was actually created with. Send it back so native shows the
    // real state, not just the requested one.
    sendToNative('ready', { cameraProjection: view.cameraProjection });
  });
```

```swift
// MapWebView.swift: the requested projection is appended to the file:// URL.
if let cameraProjection {
    queryItems.append(URLQueryItem(name: "cameraProjection", value: cameraProjection.rawValue))
}
webView.loadFileURL(urlToLoad, allowingReadAccessTo: url.deletingLastPathComponent())
```

```swift
// VisioOneBridge.swift: switching = recreating the WKWebView. The SwiftUI
// view hosting MapWebView is keyed with .id(...) on requestedCameraProjection,
// so changing it tears down the old WKWebView and loads a new page.
func reloadWithCameraProjection(_ projection: CameraProjection) {
    guard projection != requestedCameraProjection else { return }
    loadState = .loading
    cameraProjection = nil
    requestedCameraProjection = projection
}

// JS -> native ("ready" message): read back view.cameraProjection.
case "ready":
    if let payload = body["message"] as? [String: Any],
       let rawProjection = payload["cameraProjection"] as? String {
        cameraProjection = CameraProjection(rawValue: rawProjection)
    }
    loadState = .ready
```

`createView(container, venue, options?)` accepts `cameraProjection: 'perspective' | 'orthographic'` (default `'perspective'`).

## Things to know

- **Creation-time only.** `cameraProjection` is only read by `createView`. `view.cameraProjection` is a read-only getter: assigning to it doesn't change the projection, and there is no `setCameraProjection()`.
- **`?orthographic` page-URL flag.** The SDK also checks the page URL for an `orthographic` query parameter. If it's present (with any value or none), the view is forced to orthographic. The SDK merges options in this order: URL, then the options you pass, then the default. So `?orthographic` overrides `cameraProjection: 'perspective'`. It's a quick way to try orthographic without code. This app uses its own `?cameraProjection=` item instead: a presence-only flag can't request "perspective" explicitly, and it would silently override what the code asks for.
- **Don't recreate the view on the same venue.** `await visioOne.destroyView(view)` followed by `visioOne.createView(container, sameVenue, { cameraProjection: 'orthographic' })` fails in SDK 1.1.0. It throws an unhandled `Error: Cannot fetch model`, the returned promise never resolves, and the map stays black. If you switch in place rather than reloading the page, unload and reload the venue too:

  ```js
  await visioOne.destroyView(view);
  await visioOne.unloadVenue(venue);
  venue = await visioOne.loadVenue({ vg_maphash: hash });
  view = await visioOne.createView(container, venue, { cameraProjection: 'orthographic' });
  ```

  This app reloads the whole `WKWebView` page, which gives the same result: a brand-new `loadVenue` + `createView`.
- **A switch is a full map reload, and everything tied to the old view/venue is lost.** That includes event listeners (`poiclick`, `currentfloorchanged`, tracking events), runtime POIs/labels/images/markers, the camera position, the selected floor/building, any computed route, the theme and locale changes. Your app has to register its listeners again and restore any state it cares about once the new view is ready. On this app every listener is registered on page load, so a page reload re-wires them automatically. On the iOS Simulator, a switch took about 4 to 7 seconds from the tap to `ready`. That time includes re-parsing the bundled SDK, which the in-place sequence above doesn't need.
- **No sky in orthographic: the canvas is transparent.** In SDK 1.1.0 the perspective view draws a light sky behind the venue, but the orthographic view draws none and leaves the WebGL canvas transparent, so your page/container background shows through around the map (verified by giving the page a red background: the area around the map turned red in orthographic only). Give the map container the background color you want. The orthographic view also opens much more zoomed out, with the whole venue in frame.
- After a switch, the floor/building controls (`goToBuilding`/`goToFloor`) work the same way in orthographic.

## Learn more

- [Custom base URL](custom-base-url.md): the other load-time option this app changes by reloading the page.
- [Loading state](loading-state.md): the `ready`/`error` lifecycle that the reload goes through.
