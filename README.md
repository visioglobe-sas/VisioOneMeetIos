# VisioOneMeet (native iOS)

An iOS app (Swift/SwiftUI) that displays a full-screen [VisioOne](https://www.npmjs.com/package/@visioglobe/visioone) map inside a `WKWebView`. VisioOne is a **web SDK** (JS/WebGL): there is no native Swift binary, so the app bundles the SDK's JS build and a host HTML page, and drives the map through the SDK's JavaScript API from Swift.

Use this repo as a starting point for embedding VisioOne in your own native iOS app.

## Setup

### Prerequisites

- Xcode 15+ (tested with Xcode 16.2), iOS 16+
- [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`) — this project's `.xcodeproj` is generated, not checked in
- Node.js/npm — only needed if you want to refresh the vendored SDK bundle (see below); no JS build step is required to just build and run the app

### Configure your own map

The map hash is hardcoded in [`VisioOneMeet/WebContent/map.html`](VisioOneMeet/WebContent/map.html):

```js
visioOne.loadVenue({ hash: 'kbae8e6c066cca4b02c2afac2bc963a643d87437a' }, container)
```

Replace it with your own map's hash, obtained from [my.visioglobe.com](https://my.visioglobe.com) once your map has been built and published (a 41-character alphanumeric string, e.g. `kd9426d8cb3f1c532f22b5bcbd325c280bd351feb`).

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

Re-run `xcodegen generate` any time you add/remove Swift files or change the `WebContent/` structure — the project is XcodeGen-driven and does not track those changes automatically. There is no automated test target in this project.

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
- [Compute a route](docs/features/compute-navigation.md) — computes and displays a route between two POIs via `venue.computeNavigation()` → `venue.createNavigationTrace()` → `view.setCurrentNavigationTrace()`.
- [Selective UI visibility](docs/features/ui-part-visibility.md) — toggles each of the SDK's 5 default UI parts independently via `view.setUIPartVisible()`.
- [Simulated position](docs/features/simulated-position.md) — animates a simulated tracked position (with precision circle) moving between two POIs via `view.injectTrackedPosition()`.
- [Camera lock on position](docs/features/camera-lock-on-position.md) — locks the camera's focus on the currently tracked position via `view.lockCameraPositionOnTracking`.
- [Clickable surface](docs/features/clickable-surface.md) — makes a POI's surface(s) interactive via `venue.updateSurface()`, letting the SDK swap its color on hover/tap on its own.

## Architecture

- `VisioOneMeetApp.swift` — `@main` entry point, forces dark color scheme, hosts `ContentView` full-screen.
- `ContentView.swift` — the feature menu: lists `Feature.allCases`, each navigating to its own `FeatureMapView`.
- `MapWebView.swift` — the actual integration point: a `UIViewRepresentable` wrapping `WKWebView`. Configures `allowsInlineMediaPlayback`, an opaque/black background, disables scroll bounce, and loads a bundled HTML file via `webView.loadFileURL(url, allowingReadAccessTo:)` (required so WebKit can read `visioone.umd.cjs` sitting next to the HTML under `file://`).
- `FeatureMapView.swift` / `FeatureOverlays.swift` — per-feature screen hosting and the native controls (buttons, toggles, text fields) for each entry in `Feature.allCases`.
- `VisioOneBridge.swift` — the Swift ↔ JS bridge: native → JS calls go through `WKWebView.evaluateJavaScript` against `window.MapBridge` (defined in `map.html`); JS → native events come back through a `WKScriptMessageHandler` (see `docs/features/loading-state.md` and `docs/features/poi-click.md`).
- `VisioOneMeet/WebContent/` — a folder reference (not a group) so its flat file hierarchy survives into the app bundle intact:
  - `map.html` — loads `visioone.umd.cjs` via a classic `<script>` tag, calls `VisioOne.createVisioOne()`, then `visioOne.loadVenue({ hash }, container)` → `visioOne.createView(container, venue)`.
  - `diagnostic.html` — a standalone WebView repro page, not loaded by default (see `CLAUDE.md`).
  - `visioone.umd.cjs` — the vendored SDK bundle.
- `project.yml` — XcodeGen source of truth. Declares `VisioOneMeet/WebContent` as a `type: folder` / `buildPhase: resources` source so Xcode copies it as a folder reference rather than flattening it.

## Further documentation

- [`docs/INTEGRATION.md`](docs/INTEGRATION.md) — a from-scratch guide to integrating the VisioOne SDK into a native iOS app (fetching the SDK, project structure, host HTML page, Xcode/XcodeGen resource declarations, the `WKWebView` wrapper, Info.plist, build & test).
- [`docs/APP_SDK_COMMUNICATION.md`](docs/APP_SDK_COMMUNICATION.md) — bidirectional Swift ↔ JS communication (calling the SDK from native code, surfacing SDK events — e.g. a POI tap — back to SwiftUI), common pitfalls (`WKScriptMessageHandler` retain cycles, JS injection), and debugging the bridge via Safari Web Inspector.

## Toolchain gotchas

- **Never name the web assets folder `Resources`.** A folder literally named `Resources` at the root of an iOS app bundle breaks simulator (and possibly device) install with a misleading `The application's Info.plist does not contain a valid CFBundleVersion` error, even when `CFBundleVersion` is present and valid — CoreSimulator misreads it as a macOS `Contents/Resources` bundle layout. Hence the folder is named `WebContent` here.
- **Add `WebContent` as a folder reference, not a group**, both in raw Xcode (drag in, choose "Create folder references") and in `project.yml` (`type: folder`, `buildPhase: resources`, excluded from the regular sources glob) — otherwise the hierarchy gets flattened and `map.html` can't find `visioone.umd.cjs` next to it.
- **Use the UMD build (`dist/visioone.umd.cjs`), never the ESM build (`dist/visioone.js`)** — see "Refresh the vendored SDK bundle" above.
- `loadFileURL(_:allowingReadAccessTo:)` (not a plain `load(URLRequest)`) is required to let WebKit read sibling files (`visioone.umd.cjs`) from a `file://` page.
- With `GENERATE_INFOPLIST_FILE: YES` (used here), `CURRENT_PROJECT_VERSION` and `MARKETING_VERSION` must be set in build settings, or `CFBundleVersion` ends up missing, again breaking simulator/device install.
- No special `Info.plist` entries or permissions (location, camera, mic) are needed for basic map display: map data loads over HTTPS from `mapserver.visioglobe.com`, which default App Transport Security already allows.
- To debug the JS side, set `webView.isInspectable = true` (iOS 16.4+, debug builds only) and use Safari → Develop → Simulator to inspect the bundled page's console/DOM/network live.
