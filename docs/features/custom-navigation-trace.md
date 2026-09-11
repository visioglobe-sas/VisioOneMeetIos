# Custom Navigation Trace

## Description

Restyles the route drawn by [`compute-navigation`](./compute-navigation.md) with custom colors, via `venue.updateNavigationTrace(navigationTrace, options)` — the same `NavigationTrace` object created by `venue.createNavigationTrace()`, just given a `NavigationTraceUpdateOptions` object afterward.

## SDK usage

```js
// window.MapBridge, JS side
computeNavigation: function (request) {
  if (!venue || !view) return;
  var navigation = venue.computeNavigation({ /* ... */ });
  var navigationTrace = venue.createNavigationTrace(navigation);
  currentNavigationTrace = navigationTrace; // kept for a later restyle call
  view.setCurrentNavigationTrace(navigationTrace);
},
updateNavigationTrace: function (options) {
  if (!venue || !currentNavigationTrace) return;
  try {
    venue.updateNavigationTrace(currentNavigationTrace, options);
  } catch (error) {
    console.warn('updateNavigationTrace threw (trace styling still applied):', error);
  }
},
```

```swift
// VisioOneBridge, native side
func updateNavigationTrace(_ colors: NavigationTraceColors) {
    guard let webView else { return }
    let options: [String: Any] = [
        "progressColor": colors.progressColor,
        "progressOutlineColor": colors.progressOutlineColor,
        "progressFutureColor": colors.progressFutureColor,
        "previewColor": colors.previewColor,
        "previewOutlineColor": colors.previewOutlineColor,
    ]
    guard let data = try? JSONSerialization.data(withJSONObject: options),
          let json = String(data: data, encoding: .utf8) else { return }
    webView.evaluateJavaScript("window.MapBridge.updateNavigationTrace(\(json))")
}
```

`NavigationTraceUpdateOptions` (`Navigation/NavigationTraceUpdateOptions.d.ts`) only exposes colors (plus `textureRepeat`/`animationSpeed`, relevant only for the `'textured'` `displayMode`) — there is no way to change `displayMode` or `thickness` after creation, and `createNavigationTrace()` itself takes no options, so a trace always starts in the SDK's default display mode.

## Things to know

- **There is no "reset to default" call.** Colors are one-way: once changed, the only way back to the SDK's own look is to re-apply its documented defaults yourself (`Line.color` defaults to `'#0094F0'`, the inactive/preview segment to `'#C5C5C5'` — see `Venue/Line.d.ts`).
- **`updateNavigationTrace` can throw internally even on a fully valid trace.** Reproduced live against this app's own vendored SDK bundle and shared demo venue (right after creating a fresh trace): it throws `TypeError: Cannot read properties of undefined (reading 'material')` deep inside the SDK's own line-rendering pipeline. The Vue sibling app, hitting the same error on the same venue, confirmed every color in the options object is still applied correctly before it throws. Wrap the call in `try`/`catch` and treat the color change as applied regardless of whether it throws; don't treat the throw as a sign the update failed.
- Colors only affect a trace that already exists — calling `updateNavigationTrace` before `createNavigationTrace`/`setCurrentNavigationTrace` has nothing to act on. If you want a consistent look across routes, re-apply the same options object right after creating each new trace, not just once.
- Field naming is easy to mix up: `progressColor` is the segment **not yet walked** (the "active" part still ahead), while `progressFutureColor` is a second, separate color also tied to that unwalked portion — read `NavigationTraceUpdateOptions.d.ts`'s own doc comments rather than assuming from the name alone.

## Learn more

See [`compute-navigation`](./compute-navigation.md) for how the `Navigation`/`NavigationTrace` pair is computed and displayed in the first place — this feature only adds a styling call on top of it.
