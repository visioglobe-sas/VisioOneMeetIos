# Loading State

## Description

Reflects the SDK's loading/ready/error lifecycle natively, by observing the promise chain returned by `visioOne.loadVenue()` / `visioOne.createView()`, and relaying it to native code through a `WKScriptMessageHandler`.

## SDK usage

```js
// map.html
visioOne.loadVenue({ hash: '...' }, container)
  .then(function (v) { venue = v; return visioOne.createView(container, venue); })
  .then(function () {
    window.webkit.messageHandlers.mapBridge.postMessage({ type: 'ready' });
  })
  .catch(function (error) {
    visioOne.showError(error, container); // SDK helper: renders a default error UI into `container`
    window.webkit.messageHandlers.mapBridge.postMessage({
      type: 'error',
      message: error && error.message ? error.message : String(error),
    });
  });
```

```swift
// VisioOneBridge.swift
final class VisioOneBridge: NSObject, WKScriptMessageHandler, ObservableObject {
    static let messageHandlerName = "mapBridge"
    @Published private(set) var loadState: MapLoadState = .loading
    weak var webView: WKWebView?

    func userContentController(_ c: WKUserContentController, didReceive message: WKScriptMessage) {
        guard let body = message.body as? [String: Any],
              let type = body["type"] as? String else { return }
        switch type {
        case "ready": loadState = .ready
        case "error": loadState = .error(body["message"] as? String ?? "Unknown VisioOne SDK error")
        default: break
        }
    }
}
```

Registering the handler requires a weak proxy, since `WKUserContentController` retains its handler strongly (and the handler here would otherwise retain the bridge, itself retained by the owning view — a retain cycle):

```swift
final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    private weak var target: WKScriptMessageHandler?
    init(target: WKScriptMessageHandler) { self.target = target }
    func userContentController(_ c: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(c, didReceive: message)
    }
}

let contentController = WKUserContentController()
contentController.add(WeakScriptMessageHandler(target: bridge), name: VisioOneBridge.messageHandlerName)
let configuration = WKWebViewConfiguration()
configuration.userContentController = contentController
```

## Things to know

- `visioOne.showError(error, container)` is the SDK's own default error-rendering helper — it draws directly into the map container; calling it doesn't preclude also relaying the error natively.
- `WKScriptMessage.body` only carries property-list-compatible types — always `as?`, never force-cast, with a silent fallback (`default: break`) for an unexpected message shape.
- This same JS → native channel (`{type, message}` posted to a named message handler) is the general pattern reused by any other feature that needs the SDK to report something back — see `docs/features/poi-click.md` and `docs/features/floor-selector.md`.

## Learn more

- See `docs/APP_SDK_COMMUNICATION.md` for the full bidirectional bridge pattern and further WebKit pitfalls.
