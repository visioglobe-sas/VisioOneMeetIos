# Selective UI Visibility

## Description

Shows/hides each of the SDK's 5 default UI parts independently, via `view.setUIPartVisible(uiPart, isVisible)`.

## SDK usage

```js
// window.MapBridge, JS side
setUIPartVisible: function (uiPart, isVisible) {
  if (!view) return;
  view.setUIPartVisible(uiPart, isVisible);
},
```

```swift
func setUIPartVisible(_ uiPart: String, isVisible: Bool) {
    guard let webView else { return }
    guard let data = try? JSONSerialization.data(withJSONObject: uiPart, options: [.fragmentsAllowed]),
          let json = String(data: data, encoding: .utf8) else { return }
    webView.evaluateJavaScript("window.MapBridge.setUIPartVisible(\(json), \(isVisible))")
}
```

## Things to know

- **The SDK's `UIPart` type has exactly 5 values, case-sensitive**: `floorSelector`, `navigation`, `poiDetails`, `search`, `userTracking`. A typo (`poidetails`, `Navigation`, …) isn't rejected with an error — `view.setUIPartVisible` silently ignores it, the same way an unknown Place ID or floor ID does elsewhere in the SDK. Modeling the 5 values as a native enum eliminates the typo at the source rather than debugging it on the map.
- **Hiding `search` or `navigation` removes the only SDK-provided trigger for those flows** if your app has no native equivalent — unlike `floorSelector`/`poiDetails`/`userTracking`, whose disappearance doesn't block anything else from working. They can always be toggled back on to reappear.
- **No `isUIPartVisible` read is used to seed initial state here** — all 5 parts are assumed visible (`true`) at startup, matching the SDK's own documented default. A client wanting a guaranteed-synced initial state (in case something else already changed visibility before this code runs) should call `view.isUIPartVisible(part)` for each part after `createView` rather than assume the default.
- Only call `setUIPartVisible` once `view` exists (after `createView` resolves) — like most native → JS calls on this bridge, it's a silent no-op before that.

## Learn more

- `docs/features/floor-selector.md` already uses `view.setUIPartVisible('floorSelector', false)` to hide the SDK's default floor selector in favor of a native one — this feature generalizes that same call to the other 4 UI parts, without replacing any of them with a native equivalent.
- The SDK also exposes `view.showUI` (a single boolean toggling the entire UI at once) as a coarser alternative to per-part control.
