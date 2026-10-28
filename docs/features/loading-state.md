# Loading State

## Description

Reflects the SDK's loading/ready/error lifecycle natively, by observing the promise chain returned by `visioOne.loadVenue()` / `visioOne.createView()`, and relaying it to native code through a `WKScriptMessageHandler`.

## SDK usage

```js
// VisioOneMeet/WebContent/bridge/core.js
function onViewCreated(v) {
  view = v;
  runHooks(viewCreatedHooks, view);
  sendToNative('ready', { cameraProjection: view.cameraProjection });
  runHooks(readyHooks, view);
}

function onLoadError(error) {
  visioOne.showError(error, container); // SDK helper: renders a default error UI into `container`
  sendToNative('error', errorMessage(error));
}

function loadMap(loadOptions, viewOptions) {
  return visioOne.loadVenue(loadOptions, container)
    .then(function (v) {
      venue = v;
      return viewOptions
        ? visioOne.createView(container, venue, viewOptions)
        : visioOne.createView(container, venue);
    })
    .then(onViewCreated);
}

// in MapCore.start():
loadMap({ vg_maphash: hash }, undefined).catch(onLoadError);
```

`sendToNative(type, message)` posts `{ type, message }` to `window.webkit.messageHandlers.mapBridge`.

```swift
// VisioOneMeet/Bridge/VisioOneBridge.swift
@MainActor
final class VisioOneBridge: NSObject, WKScriptMessageHandler, ObservableObject {
    static let messageHandlerName = "mapBridge"
    @Published private(set) var loadState: MapLoadState = .loading
    weak var webView: WKWebView?

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == Self.messageHandlerName,
              let body = message.body as? [String: Any],
              let type = body["type"] as? String else { return }
        let payload = body["message"]

        messageHandlers[type]?.forEach { $0(payload) }

        switch type {
        case "ready":
            loadState = .ready
        case "error":
            loadState = .error(payload as? String ?? String(localized: "Unknown VisioOne SDK error"))
        // ...
        default:
            break
        }
    }
}
```

Registering the handler requires a weak proxy, since `WKUserContentController` retains its handler strongly (and the handler here would otherwise retain the bridge, itself retained by the owning view — a retain cycle):

```swift
// VisioOneMeet/Bridge/VisioOneBridge.swift
final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    private weak var target: WKScriptMessageHandler?
    init(target: WKScriptMessageHandler) { self.target = target }
    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(userContentController, didReceive: message)
    }
}

// VisioOneMeet/Shell/MapWebView.swift
let contentController = WKUserContentController()
contentController.add(WeakScriptMessageHandler(target: bridge), name: VisioOneBridge.messageHandlerName)
let configuration = WKWebViewConfiguration()
configuration.userContentController = contentController
```

## Things to know

- **The page itself can fail to load** (e.g. a missing bundled file): then no `ready`/`error` message ever arrives. Report `WKNavigationDelegate`'s `didFail`/`didFailProvisionalNavigation` as an error too (ignoring `NSURLErrorCancelled`, raised when a newer load replaces the current one), otherwise the spinner never goes away. For a Retry button, load the page URL again with `loadFileURL` rather than `WKWebView.reload()`, which does nothing when the first navigation never committed.
- `visioOne.showError(error, container)` is the SDK's own default error-rendering helper — it draws directly into the map container; calling it doesn't preclude also relaying the error natively.
- `WKScriptMessage.body` only carries property-list-compatible types — always `as?`, never force-cast, with a silent fallback (`default: break`) for an unexpected message shape.
- This same JS → native channel (`{type, message}` posted to a named message handler) is the general pattern reused by any other feature that needs the SDK to report something back — see `docs/features/poi-click.md` and `docs/features/floor-selector.md`.

## Learn more

- See `docs/APP_SDK_COMMUNICATION.md` for the full bidirectional bridge pattern and further WebKit pitfalls.
