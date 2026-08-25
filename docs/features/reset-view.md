# Reset View

## Description

Recenters the camera on the whole venue via `view.goToGlobal()` — a `View` method that takes no arguments and animates the camera back to the venue's default overview.

## SDK usage

```swift
func goToGlobal() {
    webView?.evaluateJavaScript("window.MapBridge.goToGlobal()") { _, error in
        if let error {
            print("VisioOneBridge: goToGlobal failed: \(error.localizedDescription)")
        }
    }
}
```

```js
// window.MapBridge, JS side
goToGlobal: function () {
  if (view) view.goToGlobal();
},
```

`view` is the object returned once the promise from `visioOne.createView(container, venue)` resolves — keep a reference to it, since most `View` methods (including this one) are called on it directly.

## Things to know

- Takes no arguments — no JSON-encoding needed, unlike SDK calls that take structured data.
- `view` is `null` until `createView` resolves; calling `goToGlobal` before that is a silent no-op — no error, the camera simply doesn't move.
- The camera animates back immediately when called. The `evaluateJavaScript` completion handler only reports JS-execution errors, not animation completion — there's no callback or event to await for the animation itself.

## Learn more

- See `docs/features/goto-poi.md` for `view.goToFloor()`/`view.goToPOI()`, used together for a more targeted camera move than a full reset.
