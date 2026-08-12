# Native App ↔ VisioOne SDK Communication

This guide covers how to wire up two-way communication between your native Swift code and the VisioOne JS SDK running inside the `WKWebView`. It builds on [`INTEGRATION.md`](./INTEGRATION.md), which covers the base setup (bundling the SDK, loading `map.html`, no extra permissions needed).

There are two independent channels:

| Direction | Mechanism | Use case |
|---|---|---|
| **Native → JS** | `webView.evaluateJavaScript(...)` | Trigger SDK actions from native UI (e.g. a native "recenter" button calling `view.goToGlobal()`) |
| **JS → Native** | `WKScriptMessageHandler` + `window.webkit.messageHandlers.<name>.postMessage(...)` | React natively to SDK events (e.g. show a native sheet when a POI is tapped) |

Both channels only work with content you trust — here, your own bundled `map.html`, not arbitrary remote pages.

## 1. Native → JavaScript

### 1.1 Expose a small JS API in `map.html`

Don't call SDK methods (`view.goToPOI(...)`, etc.) directly from Swift strings — wrap them in a small `window.MapBridge` object in `map.html`. This keeps the SDK's actual object model (`venue`, `view`) on the JS side, and gives Swift a stable, simple surface to call into.

```html
<script>
  var visioOne = VisioOne.createVisioOne();
  var container = document.getElementById('container');
  var currentVenue = null;
  var currentView = null;

  window.MapBridge = {
    goToGlobal: function () {
      if (currentView) currentView.goToGlobal();
    },
    goToPOI: function (poiId) {
      if (!currentView || !currentVenue) return;
      var poi = currentVenue.pois.find(function (p) { return p.id === poiId; });
      if (poi) currentView.goToFloor(poi.floor).then(function () { currentView.goToPOI(poi); });
    },
  };

  visioOne.loadVenue({ hash: 'YOUR_MAP_HASH' }, container)
    .then(function (venue) {
      currentVenue = venue;
      return visioOne.createView(container, venue);
    })
    .then(function (view) {
      currentView = view;
      // See section 2 below to forward SDK events to native.
    })
    .catch(function (error) {
      visioOne.showError(error, container);
    });
</script>
```

### 1.2 Call it from Swift

```swift
extension WKWebView {
    func callBridge(_ function: String, _ args: [String] = []) {
        let call = "window.MapBridge && window.MapBridge.\(function)(\(args.joined(separator: ", ")))"
        evaluateJavaScript(call) { _, error in
            if let error {
                print("MapBridge call failed: \(error.localizedDescription)")
            }
        }
    }
}

// Usage:
webView.callBridge("goToGlobal")
webView.callBridge("goToPOI", ["'B1-UL00-01'"]) // note: quoted, it's a JS string literal
```

> ⚠️ **Never build the JS string by directly interpolating untrusted values** (user input, server data) — you'd be re-creating a JS injection vector. If an argument comes from anywhere other than a hardcoded literal, serialize it safely:
>
> ```swift
> let poiId = "B1-UL00-01" // could come from user input
> if let jsonData = try? JSONEncoder().encode(poiId),
>    let jsonString = String(data: jsonData, encoding: .utf8) {
>     webView.callBridge("goToPOI", [jsonString]) // -> "B1-UL00-01" properly quoted/escaped
> }
> ```
>
> Or, on iOS 14.5+, prefer `webView.callAsyncJavaScript(_:arguments:in:in:completionHandler:)`, which passes arguments as real JS values (no string building at all):
>
> ```swift
> webView.callAsyncJavaScript(
>     "window.MapBridge.goToPOI(poiId);",
>     arguments: ["poiId": "B1-UL00-01"],
>     in: nil,
>     in: .page,
>     completionHandler: nil
> )
> ```

## 2. JavaScript → Native

### 2.1 Register a message handler

`WKScriptMessageHandler` lets JS code call `window.webkit.messageHandlers.<name>.postMessage(payload)`, which is delivered to a Swift object you register on the `WKWebViewConfiguration`'s `WKUserContentController` **before** creating the web view.

```swift
import WebKit
import Combine

/// Typed events the SDK forwards to native code.
enum MapEvent {
    case viewReady
    case poiSelected(id: String, name: String?)
}

final class MapBridge: NSObject, WKScriptMessageHandler {
    static let messageHandlerName = "mapBridge"

    let events = PassthroughSubject<MapEvent, Never>()

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == Self.messageHandlerName,
              let body = message.body as? [String: Any],
              let type = body["type"] as? String else { return }

        switch type {
        case "viewReady":
            events.send(.viewReady)
        case "poiSelected":
            guard let id = body["id"] as? String else { return }
            events.send(.poiSelected(id: id, name: body["name"] as? String))
        default:
            break
        }
    }
}
```

`message.body` is only ever a property-list-compatible type (`NSString`, `NSNumber`, `NSArray`, `NSDictionary`, `NSNull`, `NSDate`) — always guard-cast it, never force-cast.

### 2.2 Avoid the retain-cycle pitfall

`WKUserContentController.add(_:name:)` **strongly retains** the handler. If the handler is your `Coordinator` (which the web view's configuration also indirectly keeps alive), you create a reference cycle that leaks the web view. The standard fix is a weak proxy:

```swift
final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    private weak var target: WKScriptMessageHandler?

    init(target: WKScriptMessageHandler) {
        self.target = target
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(userContentController, didReceive: message)
    }
}
```

Register the proxy instead of `self`, and remove the handler when the view is torn down:

```swift
struct MapWebView: UIViewRepresentable {
    let bridge = MapBridge()

    func makeUIView(context: Context) -> WKWebView {
        let contentController = WKUserContentController()
        contentController.add(WeakScriptMessageHandler(target: bridge), name: MapBridge.messageHandlerName)

        let configuration = WKWebViewConfiguration()
        configuration.userContentController = contentController

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.navigationDelegate = context.coordinator

        if let url = Bundle.main.url(forResource: "map", withExtension: "html", subdirectory: "WebContent") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: MapBridge.messageHandlerName)
    }

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, WKNavigationDelegate {}
}
```

### 2.3 Forward SDK events from `map.html`

VisioOne's `View.addEventListener(type, callback)` follows the standard `EventTarget` semantics. Subscribe to the events you care about (see the full list in `EventType.d.ts` — `poiclick`, `selectedpoischange`, `navigationstarted`, `currentfloorchanged`, `trackingon`, …) and relay them through the bridge:

```js
visioOne.createView(container, venue).then(function (view) {
  currentView = view;

  window.webkit.messageHandlers.mapBridge.postMessage({ type: 'viewReady' });

  view.addEventListener('poiclick', function (event) {
    var poi = event.pois[0];
    if (!poi) return;
    window.webkit.messageHandlers.mapBridge.postMessage({
      type: 'poiSelected',
      id: poi.id,
      name: poi.labels[0] ? poi.labels[0].text : null,
    });
  });
});
```

### 2.4 React to events in SwiftUI

```swift
final class MapViewModel: ObservableObject {
    @Published var selectedPOIName: String?
    private var cancellable: AnyCancellable?

    init(bridge: MapBridge) {
        cancellable = bridge.events.sink { [weak self] event in
            switch event {
            case .viewReady:
                break
            case .poiSelected(_, let name):
                self?.selectedPOIName = name
            }
        }
    }
}
```

`ContentView` can then show a native overlay (banner, sheet, `.alert`) whenever `selectedPOIName` changes — running alongside, or instead of, the SDK's own `poiDetails` panel (`view.setUIPartVisible('poiDetails', false)` if you want the native UI to fully replace it).

## 3. Debugging the bridge

On iOS 16.4+ / macOS 13.3+, set `webView.isInspectable = true` (debug builds only) to inspect the bundled page from **Safari → Develop → Simulator → map.html**: full console, DOM, and network panel for the WKWebView content. This is the fastest way to confirm your `postMessage` payloads and `MapBridge` calls actually fire as expected.

```swift
#if DEBUG
if #available(iOS 16.4, *) {
    webView.isInspectable = true
}
#endif
```

## 4. Summary checklist

- [ ] `map.html` exposes a small `window.MapBridge` object — Swift never touches `venue`/`view` internals directly.
- [ ] Arguments passed from Swift into JS are JSON-encoded or sent via `callAsyncJavaScript`, never raw string interpolation.
- [ ] `WKScriptMessageHandler` is registered through a **weak proxy**, and removed in `dismantleUIView`.
- [ ] `message.body` is guard-cast, never force-cast.
- [ ] SDK events you actually need are forwarded via `postMessage`; you're not force-polling JS state from native.
- [ ] `isInspectable` is enabled in debug builds to inspect the page live.
