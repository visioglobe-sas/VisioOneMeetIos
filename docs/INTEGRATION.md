# Integrating the VisioOne SDK into a native iOS app

This guide shows how to display a [VisioOne](https://www.npmjs.com/package/@visioglobe/visioone) map in a native iOS app (Swift/SwiftUI) by embedding the JavaScript SDK in a `WKWebView`.

VisioOne is a **web** SDK (JS/WebGL): there is no native Swift binary. A native integration therefore means:

1. bundling the JS SDK and a host HTML page in the app bundle,
2. displaying that page in a full-screen `WKWebView`,
3. driving the map through the SDK's JS API (loading a venue, navigation, etc.).

No system permission (location, camera…) is needed for basic map display.

## Prerequisites

- Xcode 15+ (tested with Xcode 16.2), iOS 16+
- Node.js/npm (only to fetch the SDK; no JS build is needed afterwards)
- A valid **map hash**, obtained from [my.visioglobe.com](https://my.visioglobe.com) (a 41-character alphanumeric string, e.g. `kd9426d8cb3f1c532f22b5bcbd325c280bd351feb` — the map must have been built first)

## 1. Fetch the SDK

The SDK is distributed as an npm package:

```bash
npm pack @visioglobe/visioone
tar xzf visioglobe-visioone-*.tgz
```

The file you need is **`package/dist/visioone.umd.cjs`**: a self-contained UMD bundle (~5 MB) that embeds its own CSS and assets (icons, animations) as base64. It is loaded as-is in a `<script>` tag, with no bundler or transpilation.

> ⚠️ Do not use `dist/visioone.js` (the ESM build) as-is in a WebView: it references JS chunks loaded dynamically via `import()`, which fails under `file://` in WebKit (CORS restrictions on local ES modules). The **UMD** bundle avoids this.

## 2. Project structure

```
MyApp/
├── MyApp.xcodeproj
└── MyApp/
    ├── MyAppApp.swift
    ├── ContentView.swift
    ├── MapWebView.swift        // WKWebView wrapper
    └── WebContent/             // ⚠️ see the warning below
        ├── map.html
        └── visioone.umd.cjs
```

> ⚠️ **Never name this folder `Resources`.** A folder literally named `Resources` at the root of an iOS app bundle makes installation fail on the simulator (and possibly on device) with a misleading error:
> ```
> The application's Info.plist does not contain a valid CFBundleVersion.
> ```
> even when `CFBundleVersion` is present and valid. CoreSimulator mistakes a `Resources` folder for the `Contents/Resources` layout of a macOS bundle and fails to find the `Info.plist` where it expects it. Use another name (`WebContent`, `WebAssets`, etc.).

## 3. The host HTML page

Create `WebContent/map.html`. Once loaded with a classic `<script>` tag (not `type="module"`), the SDK is exposed as `window.VisioOne`:

```html
<!DOCTYPE html>
<html lang="en">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no, viewport-fit=cover" />
  <title>VisioOne Map</title>
  <style>
    html, body { margin: 0; padding: 0; width: 100%; height: 100%; background: #000; overflow: hidden; }
    #container { position: absolute; top: 0; left: 0; width: 100%; height: 100%; }
  </style>
  <script src="visioone.umd.cjs"></script>
</head>
<body>
  <div id="container"></div>
  <script>
    var visioOne = VisioOne.createVisioOne();
    var container = document.getElementById('container');

    visioOne.loadVenue({ vg_maphash: 'YOUR_MAP_HASH' }, container)
      .then(function (venue) {
        return visioOne.createView(container, venue);
      })
      .catch(function (error) {
        visioOne.showError(error, container);
      });
  </script>
</body>
</html>
```

Replace `YOUR_MAP_HASH` with your map's hash.

### Essential JS API

| Call | Purpose |
|---|---|
| `VisioOne.createVisioOne()` | Creates the SDK's main instance. |
| `visioOne.loadVenue({ vg_maphash, baseURL?, disableCache?, authorizationToken? }, container)` | Loads the map data (`container` shows a loader meanwhile). Returns a `Promise<Venue>`. |
| `visioOne.createView(container, venue, options?)` | Creates the interactive 3D map view in `container`. Returns a `Promise<View>`. |
| `visioOne.showError(error, container)` | Shows an error in the SDK's UI (otherwise it only goes to the console). |
| `visioOne.unloadVenue(venue)` / `visioOne.destroyView(view)` | Releases resources (useful when switching maps or closing a screen). |

`createView`'s `options` include `zoomSpeed`, `cameraProjection` (`perspective`/`orthographic`), `zenithalMode`, `lockPitch`.

The whole API (POIs, navigation, markers, events…) is documented on [my.visioglobe.com/docs](https://my.visioglobe.com/docs/) and in the `.d.ts` files shipped with the npm package.

## 4. Declare the resources in the Xcode project

Add the `WebContent` folder as a **folder reference** (blue icon), not as a group, so its hierarchy is kept in the app bundle (otherwise the files are flattened and `map.html` won't find `visioone.umd.cjs` next to it).

**In Xcode:** drag the `WebContent` folder into the project navigator and choose **"Create folder references"** (not "Create groups").

**With [XcodeGen](https://github.com/yonaskolb/XcodeGen)** (`project.yml`):

```yaml
targets:
  MyApp:
    type: application
    platform: iOS
    sources:
      - path: MyApp
        excludes:
          - "WebContent/**"
      - path: MyApp/WebContent
        type: folder
        buildPhase: resources
```

## 5. The SwiftUI / WKWebView wrapper

```swift
import SwiftUI
import WebKit

struct MapWebView: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.bounces = false
        webView.navigationDelegate = context.coordinator

        if let url = Bundle.main.url(forResource: "map", withExtension: "html", subdirectory: "WebContent") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("VisioOne map load failed: \(error.localizedDescription)")
        }
    }
}
```

```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        MapWebView()
            .ignoresSafeArea()
    }
}
```

`loadFileURL(_:allowingReadAccessTo:)` is required: it lets WebKit read, from a `file://` page, every file of the folder passed as second argument (here `WebContent/`), hence `visioone.umd.cjs` next to `map.html`.

## 6. Info.plist

No specific entry is needed:

- The SDK loads map data over **HTTPS** (`https://mapserver.visioglobe.com/` by default), which iOS's default App Transport Security allows without any exception.
- No permission (location, camera, microphone…) is requested for standard map display. If you enable features that need one (e.g. the user's real location), add the matching key, such as `NSLocationWhenInUseUsageDescription`.
- If you use `GENERATE_INFOPLIST_FILE: YES` (modern Xcode / XcodeGen), set `CURRENT_PROJECT_VERSION` and `MARKETING_VERSION` in the build settings: without them `CFBundleVersion` is missing and installing on a simulator/device fails.

## 7. Build & test

```bash
xcodebuild -project MyApp.xcodeproj -scheme MyApp -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' build
```

Then install/launch on a booted simulator:

```bash
xcrun simctl install <UDID> path/to/MyApp.app
xcrun simctl launch <UDID> com.example.myapp
```

A screenshot (`xcrun simctl io <UDID> screenshot out.png`) lets you check the map rendering visually.

## Going further

- **Native ↔ JS communication**: to drive the map from Swift (e.g. a native button centering the map on a POI) and to bring JS events (POI tap, navigation end…) back to Swift, see [`APP_SDK_COMMUNICATION.md`](./APP_SDK_COMMUNICATION.md).
- **Growing the page past one script**: once the JS side holds more than a few commands, split it into classic `<script src>` files loaded in order from `map.html` (never `type="module"`, which fails under `file://`) — this repo uses `WebContent/bridge/core.js` (loading, `window.MapBridge`, shared helpers), one `WebContent/features/<slug>.js` per feature, then `WebContent/bridge/bootstrap.js`. Subfolders of a folder reference are copied as-is, and `loadFileURL(_:allowingReadAccessTo:)` on the `WebContent/` directory lets the page read them. See the README's "Architecture" section.
- **UI customization**, **POI management**, **multimodal routing**, **custom markers**: see the full documentation on [my.visioglobe.com/docs](https://my.visioglobe.com/docs/) and this repo's `docs/features/`.
- **Support**: [Visioglobe support portal](https://my.visioglobe.com/support).
