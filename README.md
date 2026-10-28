# VisioOneMeet (native iOS)

An iOS app (Swift/SwiftUI) that displays a full-screen [VisioOne](https://www.npmjs.com/package/@visioglobe/visioone) map inside a `WKWebView`. VisioOne is a **web SDK** (JS/WebGL): there is no native Swift binary, so the app bundles the SDK's JS build and a host HTML page, and drives the map through the SDK's JavaScript API from Swift.

Use this repo as a starting point for embedding VisioOne in your own native iOS app.

## Setup

### Prerequisites

- Xcode 15+ (tested with Xcode 16.2), iOS 16+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`) — `VisioOneMeet.xcodeproj` is generated from `project.yml`; the generated project is committed so the repo builds as cloned, but regenerate it after adding/removing files
- Node.js/npm — only needed if you want to refresh the vendored SDK bundle (see below); no JS build step is required to just build and run the app

### Configure your own map

The map hash and every demo POI id used to prefill the feature screens' fields live in one file, [`VisioOneMeet/Shared/DemoMap.swift`](VisioOneMeet/Shared/DemoMap.swift):

```swift
enum DemoMap {
    static let mapHash = "kbae8e6c066cca4b02c2afac2bc963a643d87437a"
    static let gotoPoiId = "B3-UL00-ID0076"
    // ...
}
```

The native side passes the hash to the page ([`map.html`](VisioOneMeet/WebContent/map.html)) as a `?vg_maphash=` query param, which [`bridge/core.js`](VisioOneMeet/WebContent/bridge/core.js) hands to `visioOne.loadVenue({ vg_maphash }, container)`. Replace it with your own map's hash, obtained from [my.visioglobe.com](https://my.visioglobe.com) once your map has been built and published (a 41-character alphanumeric string, e.g. `kd9426d8cb3f1c532f22b5bcbd325c280bd351feb`), and the POI ids with ids from your own map.

The option is named `vg_maphash` since VisioOne SDK 1.0.6 (it used to be `hash`). The SDK silently ignores an old `hash` option, and the load then fails with `Cannot load the venue`.

### Generate the Xcode project and build/run

```bash
xcodegen generate       # regenerates VisioOneMeet.xcodeproj from project.yml
open VisioOneMeet.xcodeproj
```

Then build/run from Xcode (⌘R), or from the command line:

```bash
xcodebuild -project VisioOneMeet.xcodeproj -scheme VisioOneMeet \
  -destination 'generic/platform=iOS Simulator' build
```

Re-run `xcodegen generate` any time you add/remove Swift files or change the `WebContent/` structure (a new `WebContent/features/<slug>.js` also needs its `<script>` tag in `map.html`) — the project is XcodeGen-driven and does not track those changes automatically. There is no automated test target in this project.

### Refresh the vendored SDK bundle

The SDK is vendored as a pre-built file, `VisioOneMeet/WebContent/visioone.umd.cjs` (~5 MB, CSS/assets inlined as base64) — there is no bundler/transpile step. To update it:

```bash
npm pack @visioglobe/visioone
tar xzf visioglobe-visioone-*.tgz
```

Copy **`package/dist/visioone.umd.cjs`** over the existing file. Do not use `dist/visioone.js` (the ESM build): it dynamically `import()`s chunks at runtime, which fails under WebKit's CORS restrictions on ES modules loaded from `file://`.

## Features

Each feature below is a self-contained screen demonstrating one part of the VisioOne SDK API. Each links to a doc detailing the exact SDK calls involved.

- [Loading state](docs/features/loading-state.md) — reflects the SDK's loading/ready/error lifecycle in native SwiftUI (spinner, retry button) instead of a blank WebView.
- [Reset view](docs/features/reset-view.md) — a native button that recenters the camera on the whole venue via `view.goToGlobal()`.
- [Occupancy (simulated data)](docs/features/occupancy-simulated.md) — colors a POI's surface to reflect an occupancy status (free/soon-busy/busy) via `venue.updateSurface()`.
- [React to a POI tap](docs/features/poi-click.md) — shows a native panel with a POI's name and ID by subscribing to the SDK's `poiclick` event.
- [Go to a POI](docs/features/goto-poi.md) — centers and zooms the camera on a POI given its ID via `view.goToPOI()`, with a surface highlight.
- [Floor/building selector](docs/features/floor-selector.md) — changes floor/building via `view.goToFloor()`/`view.goToBuilding()`, driven from a native list built from `venue.venueLayout`.
- [Explore mode](docs/features/explore-mode.md) — switches between the SDK's 3 building-exploration modes (global / exploded building carousel / floor) via `view.currentExploreMode`, kept in sync with the SDK's own state via the `exploremodechanged` event.
- [Compute a route](docs/features/compute-navigation.md) — computes and displays a route between two POIs via `venue.computeNavigation()` → `venue.createNavigationTrace()` → `view.setCurrentNavigationTrace()`.
- [Selective UI visibility](docs/features/ui-part-visibility.md) — toggles each of the SDK's 5 default UI parts independently via `view.setUIPartVisible()`.
- [Native UI replacement](docs/features/native-ui-replacement.md) — hides the SDK's default floor-selector widget via `view.setUIPartVisible()` and shows the app's own native floor picker as a complete, fully-functional replacement.
- [Simulated position](docs/features/simulated-position.md) — animates a simulated tracked position (with precision circle) moving between two POIs via `view.injectTrackedPosition()`.
- [Camera lock on position](docs/features/camera-lock-on-position.md) — locks the camera's focus on the currently tracked position via `view.lockCameraPositionOnTracking`.
- [Clickable surface](docs/features/clickable-surface.md) — makes a POI's surface(s) interactive via `venue.updateSurface()`, letting the SDK swap its color on hover/tap on its own.
- [Custom data](docs/features/custom-data.md) — reads business CustomData (price, hours, reference) attached to a POI via `venue.refreshCustomData()` + `venue.getPOICustomData()`.
- [Category highlight](docs/features/category-highlight.md) — highlights every POI of a chosen category (e.g. all shops) in one action, via `venue.categories`/`poi.categories` + `venue.updateSurface()`.
- [Dynamic POI CRUD](docs/features/dynamic-poi-crud.md) — creates, edits, and removes a POI at runtime without republishing the map, via `venue.createPOI()`/`venue.createLabel()`/`venue.updateLabel()`/`venue.removePOI()`.
- [Runtime locale](docs/features/runtime-locale.md) — switches the map's displayed language (POI/label names) at runtime without reloading, via `venue.currentLocale`/`venue.setCurrentLocale()`.
- [Add locale](docs/features/add-locale.md) — adds a brand-new locale never authored in VisioMapEditor via `venue.translator.addLocale()`, then reads it back via `venue.translator.translate()`.
- [Geofencing](docs/features/geofencing.md) — highlights a zone POI's surface whenever a simulated tracked position enters it, via a point-in-polygon check against `Surface.positions`.
- [Custom base URL](docs/features/custom-base-url.md) — points the SDK at a different map server via `loadVenue`'s `baseURL` option, reloading the venue against whatever value is typed.
- [Custom navigation trace](docs/features/custom-navigation-trace.md) — restyles a computed route with a color preset via `venue.updateNavigationTrace()`, applied immediately to the current trace and remembered for the next one.
- [Exclude modalities](docs/features/navigation-exclude-modalities.md) — computes a route while avoiding a segment modality (e.g. elevators) via `venue.computeNavigation()`'s `excludedAttributes` option.
- [Accessible route](docs/features/accessible-mode.md) — computes a route that only uses the venue's own accessible path via `venue.computeNavigation()`'s `isAccessible` option.
- [3D icon marker](docs/features/3d-icon-marker.md) — places a custom image (here a data-URL PNG icon) at a POI's position in the 3D scene via `venue.createImage()`, switches its orientation live via `venue.updateImage()`, and removes it via `venue.removeImage()`.
- [Custom text label](docs/features/custom-text-label.md) — places your own free text (opening hours, a price, a zone name…) next to a POI via `venue.createLabel()`, restyles it live (text, color, size) via `venue.updateLabel()`, and removes it via `venue.removeLabel()`.
- [HTML overlay marker](docs/features/html-overlay-marker.md) — pins a tappable HTML badge on the map via `venue.createMarker({ element })`, drawn above the 3D scene (never hidden by geometry), forwards its taps to native, shows/hides it via `venue.updateMarker()` and removes it via `venue.removeMarker()`.
- [Custom theme](docs/features/custom-theme.md) — switches the 3D scene lighting theme via `view.themes`/`view.setTheme()` (view created with `enableShadows: true`) and recolors the SDK's own UI buttons live via `view.accentColor`/`view.textAccentColor`.
- [Accuracy circle style](docs/features/accuracy-circle-style.md) — recolors the tracked position's precision circle live (color presets + opacity) via `view.updatePositionTrackerGraphicOptions()`, on top of the simulated-position loop.
- [Camera projection](docs/features/camera-projection-toggle.md) — switches between a 3D perspective view and a flat orthographic view via `createView()`'s `cameraProjection` option (creation-time only, so each switch reloads the map), showing the projection reported by the read-only `view.cameraProjection`.
- [Camera showcase](docs/features/camera-showcase-carousel.md) — an automatic camera tour of the map for kiosks and lobby screens, looping `view.goToFloor()` + `view.goToPOI()` (custom duration, easing and heading/pitch) over a list of POIs; a touch on the map pauses it in place and it resumes after 10 s idle.
- [Protected map (token)](docs/features/auth-token.md) — **code sample** (placeholder values, not loaded by the demo): loads a map protected by a JWT via `loadVenue()`'s `authorizationToken` + `baseURL` options, refreshes it via `venue.setAuthorizationToken()`, and reports the SDK's `UnauthorizedError` apart from other load errors.

## Where is the code of feature X?

In two places, both named after the feature's slug (the name of its doc in `docs/features/`):

- **Swift:** `VisioOneMeet/Features/<Feature>/` — `<Feature>Panel.swift` (the controls in the bottom sheet), `<Feature>Model.swift` (the feature's state, owned by the screen) and `<Feature>+Bridge.swift` (its calls into the page, as a `VisioOneBridge` extension). The folder name is the slug in PascalCase (`goto-poi` → `GotoPoi/`, `3d-icon-marker` → `3dIconMarker/`).
- **JS:** `VisioOneMeet/WebContent/features/<slug>.js` — the actual SDK calls, added to `window.MapBridge`.

A few features reuse another one's calls instead of having their own: accessible-mode uses compute-navigation's `computeNavigation` and navigation-exclude-modalities' `clearNavigationTrace`; native-ui-replacement reuses floor-selector's list and ui-part-visibility's `setUIPartVisible`; the four tracking screens share `Shared/PositionTracking/` and simulated-position's calls. custom-base-url and camera-projection-toggle only change a load option of the page, read by `bridge/core.js`. loading-state is the screen shell itself (`Shell/FeatureScreen.swift`, `Bridge/VisioOneBridge.swift`).

| Feature | Swift | JS |
|---|---|---|
| [reset-view](docs/features/reset-view.md) | [`Features/ResetView/`](VisioOneMeet/Features/ResetView) | [`features/reset-view.js`](VisioOneMeet/WebContent/features/reset-view.js) |
| [occupancy-simulated](docs/features/occupancy-simulated.md) | [`Features/OccupancySimulated/`](VisioOneMeet/Features/OccupancySimulated) | [`features/occupancy-simulated.js`](VisioOneMeet/WebContent/features/occupancy-simulated.js) |
| [poi-click](docs/features/poi-click.md) | [`Features/PoiClick/`](VisioOneMeet/Features/PoiClick) | [`features/poi-click.js`](VisioOneMeet/WebContent/features/poi-click.js) |
| [goto-poi](docs/features/goto-poi.md) | [`Features/GotoPoi/`](VisioOneMeet/Features/GotoPoi) | [`features/goto-poi.js`](VisioOneMeet/WebContent/features/goto-poi.js) |
| [floor-selector](docs/features/floor-selector.md) | [`Features/FloorSelector/`](VisioOneMeet/Features/FloorSelector) | [`features/floor-selector.js`](VisioOneMeet/WebContent/features/floor-selector.js) |
| [explore-mode](docs/features/explore-mode.md) | [`Features/ExploreMode/`](VisioOneMeet/Features/ExploreMode) | [`features/explore-mode.js`](VisioOneMeet/WebContent/features/explore-mode.js) |
| [compute-navigation](docs/features/compute-navigation.md) | [`Features/ComputeNavigation/`](VisioOneMeet/Features/ComputeNavigation) | [`features/compute-navigation.js`](VisioOneMeet/WebContent/features/compute-navigation.js) |
| [ui-part-visibility](docs/features/ui-part-visibility.md) | [`Features/UiPartVisibility/`](VisioOneMeet/Features/UiPartVisibility) | [`features/ui-part-visibility.js`](VisioOneMeet/WebContent/features/ui-part-visibility.js) |
| [native-ui-replacement](docs/features/native-ui-replacement.md) | [`Features/NativeUiReplacement/`](VisioOneMeet/Features/NativeUiReplacement) | — |
| [simulated-position](docs/features/simulated-position.md) | [`Features/SimulatedPosition/`](VisioOneMeet/Features/SimulatedPosition) | [`features/simulated-position.js`](VisioOneMeet/WebContent/features/simulated-position.js) |
| [camera-lock-on-position](docs/features/camera-lock-on-position.md) | [`Features/CameraLockOnPosition/`](VisioOneMeet/Features/CameraLockOnPosition) | [`features/camera-lock-on-position.js`](VisioOneMeet/WebContent/features/camera-lock-on-position.js) |
| [clickable-surface](docs/features/clickable-surface.md) | [`Features/ClickableSurface/`](VisioOneMeet/Features/ClickableSurface) | [`features/clickable-surface.js`](VisioOneMeet/WebContent/features/clickable-surface.js) |
| [custom-data](docs/features/custom-data.md) | [`Features/CustomData/`](VisioOneMeet/Features/CustomData) | [`features/custom-data.js`](VisioOneMeet/WebContent/features/custom-data.js) |
| [category-highlight](docs/features/category-highlight.md) | [`Features/CategoryHighlight/`](VisioOneMeet/Features/CategoryHighlight) | [`features/category-highlight.js`](VisioOneMeet/WebContent/features/category-highlight.js) |
| [dynamic-poi-crud](docs/features/dynamic-poi-crud.md) | [`Features/DynamicPoiCrud/`](VisioOneMeet/Features/DynamicPoiCrud) | [`features/dynamic-poi-crud.js`](VisioOneMeet/WebContent/features/dynamic-poi-crud.js) |
| [runtime-locale](docs/features/runtime-locale.md) | [`Features/RuntimeLocale/`](VisioOneMeet/Features/RuntimeLocale) | [`features/runtime-locale.js`](VisioOneMeet/WebContent/features/runtime-locale.js) |
| [add-locale](docs/features/add-locale.md) | [`Features/AddLocale/`](VisioOneMeet/Features/AddLocale) | [`features/add-locale.js`](VisioOneMeet/WebContent/features/add-locale.js) |
| [geofencing](docs/features/geofencing.md) | [`Features/Geofencing/`](VisioOneMeet/Features/Geofencing) | [`features/geofencing.js`](VisioOneMeet/WebContent/features/geofencing.js) |
| [custom-base-url](docs/features/custom-base-url.md) | [`Features/CustomBaseUrl/`](VisioOneMeet/Features/CustomBaseUrl) | — |
| [custom-navigation-trace](docs/features/custom-navigation-trace.md) | [`Features/CustomNavigationTrace/`](VisioOneMeet/Features/CustomNavigationTrace) | [`features/custom-navigation-trace.js`](VisioOneMeet/WebContent/features/custom-navigation-trace.js) |
| [navigation-exclude-modalities](docs/features/navigation-exclude-modalities.md) | [`Features/NavigationExcludeModalities/`](VisioOneMeet/Features/NavigationExcludeModalities) | [`features/navigation-exclude-modalities.js`](VisioOneMeet/WebContent/features/navigation-exclude-modalities.js) |
| [accessible-mode](docs/features/accessible-mode.md) | [`Features/AccessibleMode/`](VisioOneMeet/Features/AccessibleMode) | — |
| [3d-icon-marker](docs/features/3d-icon-marker.md) | [`Features/3dIconMarker/`](VisioOneMeet/Features/3dIconMarker) | [`features/3d-icon-marker.js`](VisioOneMeet/WebContent/features/3d-icon-marker.js) |
| [custom-text-label](docs/features/custom-text-label.md) | [`Features/CustomTextLabel/`](VisioOneMeet/Features/CustomTextLabel) | [`features/custom-text-label.js`](VisioOneMeet/WebContent/features/custom-text-label.js) |
| [html-overlay-marker](docs/features/html-overlay-marker.md) | [`Features/HtmlOverlayMarker/`](VisioOneMeet/Features/HtmlOverlayMarker) | [`features/html-overlay-marker.js`](VisioOneMeet/WebContent/features/html-overlay-marker.js) |
| [custom-theme](docs/features/custom-theme.md) | [`Features/CustomTheme/`](VisioOneMeet/Features/CustomTheme) | [`features/custom-theme.js`](VisioOneMeet/WebContent/features/custom-theme.js) |
| [accuracy-circle-style](docs/features/accuracy-circle-style.md) | [`Features/AccuracyCircleStyle/`](VisioOneMeet/Features/AccuracyCircleStyle) | [`features/accuracy-circle-style.js`](VisioOneMeet/WebContent/features/accuracy-circle-style.js) |
| [camera-projection-toggle](docs/features/camera-projection-toggle.md) | [`Features/CameraProjectionToggle/`](VisioOneMeet/Features/CameraProjectionToggle) | — |
| [camera-showcase-carousel](docs/features/camera-showcase-carousel.md) | [`Features/CameraShowcaseCarousel/`](VisioOneMeet/Features/CameraShowcaseCarousel) | [`features/camera-showcase-carousel.js`](VisioOneMeet/WebContent/features/camera-showcase-carousel.js) |
| [auth-token](docs/features/auth-token.md) | [`Features/AuthToken/`](VisioOneMeet/Features/AuthToken) | [`features/auth-token.js`](VisioOneMeet/WebContent/features/auth-token.js) |

## Architecture

`VisioOneMeet/`:

- `App/` — `VisioOneMeetApp.swift` (`@main` entry point, forces the dark color scheme) and `ContentView.swift` (the feature menu, listing `Feature.all`).
- `Shell/` — what every feature screen shares:
  - `Feature.swift` — the feature registry: one table of slug, localized title/description, page options (map hash, `baseURL`, `enableShadows`, `cameraProjection`) and the factory of the feature's model.
  - `FeatureScreen.swift` — one screen per feature: the map, the FAB and the control sheet. The sheet shows the panel of the feature's model; the model is created once per screen, so closing and reopening the sheet shows the real current state, and leaving the screen stops whatever it runs.
  - `FeatureModel.swift` — the protocol every feature model implements (panel, panel trigger, map-ready / panel-dismissed / screen-left hooks).
  - `MapWebView.swift` — the actual integration point: a `UIViewRepresentable` wrapping `WKWebView`. Configures `allowsInlineMediaPlayback`, a black background (`isOpaque = false`, so nothing flashes white while the page loads), disables scroll bounce, passes the page options as query items, and loads the bundled page via `webView.loadFileURL(url, allowingReadAccessTo:)` (required so WebKit can read the sibling scripts under `file://`). A failure to load the page itself is reported to the bridge, which shows the error screen.
- `Bridge/` — `VisioOneBridge.swift`, the core of the Swift ↔ JS bridge: native → JS calls go to `window.MapBridge` through generic `call` / `callForResult` / `callForStatus` helpers over `WKWebView.callAsyncJavaScript` (arguments passed as real JS values, Promises awaited); JS → native messages come back through a `WKScriptMessageHandler` and are dispatched to the features that registered for them. `BridgeResult.swift` maps the `{ status }` results. Each feature's own calls are extensions in its folder (see `docs/APP_SDK_COMMUNICATION.md`).
- `Features/<Feature>/` — one folder per feature (see "Where is the code of feature X?").
- `Shared/` — `DemoMap.swift` (the demo map hash and POI ids, see "Configure your own map"), `PositionTracking/` (the simulated position loop and its controls, shared by the four tracking screens) and `Components/` (POI id field, From/To fields, color chip, hex colors, error messages of the placed-object screens).
- `Localizable.xcstrings` — every user-visible string, in English and French.
- `WebContent/` — a folder reference (not a group) so its file hierarchy survives into the app bundle intact:
  - `map.html` — the page skeleton: loads `visioone.umd.cjs`, then classic `<script>` tags in order `bridge/core.js` → `features/<slug>.js` → `bridge/bootstrap.js`. No ES modules: they fail under `file://`.
  - `bridge/core.js` — `window.MapBridge`, `sendToNative` (the JS → native channel), the shared helpers (`findPoi`, `poiDisplayPosition`, `offsetPosition`, `showNavigation`), the map loading (`visioOne.loadVenue` → `visioOne.createView`, with the page options read from the query string) and the `MapCore` registration API each feature file uses (`register`, `onViewCreated`, `onReady`, `onReset`).
  - `features/<slug>.js` — one file per feature, adding its commands to `window.MapBridge`.
  - `bridge/bootstrap.js` — starts the map load once every feature file is in.
  - `visioone.umd.cjs` — the vendored SDK bundle.

`project.yml` is the XcodeGen source of truth. It declares `VisioOneMeet/WebContent` as a `type: folder` / `buildPhase: resources` source so Xcode copies it as a folder reference rather than flattening it.

## Further documentation

- [`docs/INTEGRATION.md`](docs/INTEGRATION.md) — a from-scratch guide to integrating the VisioOne SDK into a native iOS app (fetching the SDK, project structure, host HTML page, Xcode/XcodeGen resource declarations, the `WKWebView` wrapper, Info.plist, build & test).
- [`docs/APP_SDK_COMMUNICATION.md`](docs/APP_SDK_COMMUNICATION.md) — bidirectional Swift ↔ JS communication (calling the SDK from native code, surfacing SDK events — e.g. a POI tap — back to SwiftUI), common pitfalls (`WKScriptMessageHandler` retain cycles, JS injection), and debugging the bridge via Safari Web Inspector.

## Toolchain gotchas

- **Never name the web assets folder `Resources`.** A folder literally named `Resources` at the root of an iOS app bundle breaks simulator (and possibly device) install with a misleading `The application's Info.plist does not contain a valid CFBundleVersion` error, even when `CFBundleVersion` is present and valid — CoreSimulator misreads it as a macOS `Contents/Resources` bundle layout. Hence the folder is named `WebContent` here.
- **Add `WebContent` as a folder reference, not a group**, both in raw Xcode (drag in, choose "Create folder references") and in `project.yml` (`type: folder`, `buildPhase: resources`, excluded from the regular sources glob) — otherwise the hierarchy gets flattened and `map.html` can't find `visioone.umd.cjs` and its `bridge/`/`features/` scripts.
- **Use the UMD build (`dist/visioone.umd.cjs`), never the ESM build (`dist/visioone.js`)** — see "Refresh the vendored SDK bundle" above.
- `loadFileURL(_:allowingReadAccessTo:)` (not a plain `load(URLRequest)`) is required to let WebKit read sibling files (`visioone.umd.cjs`, `bridge/`, `features/`) from a `file://` page.
- With `GENERATE_INFOPLIST_FILE: YES` (used here), `CURRENT_PROJECT_VERSION` and `MARKETING_VERSION` must be set in build settings, or `CFBundleVersion` ends up missing, again breaking simulator/device install.
- No special `Info.plist` entries or permissions (location, camera, mic) are needed for basic map display: map data loads over HTTPS from `mapserver.visioglobe.com`, which default App Transport Security already allows.
- To debug the JS side, set `webView.isInspectable = true` (iOS 16.4+, debug builds only) and use Safari → Develop → Simulator to inspect the bundled page's console/DOM/network live.
