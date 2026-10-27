# Native UI Replacement

## Description

Demonstrates that an app's own fully-native UI can completely replace one of the SDK's default UI components, rather than merely coexisting with it. It hides the SDK's own default floor-selector widget via `view.setUIPartVisible('floorSelector', false)` and shows that this repo's existing native floor/building picker (built for [`floor-selector`](./floor-selector.md), driving `view.goToFloor()`/`view.goToBuilding()` off the real `venue.venueLayout` data) is, on its own, a complete and fully-functional replacement — no visual duplication of two floor pickers.

The SDK widget starts hidden by default, so only the app's native picker is visible and functional. A "Show SDK's own floor selector" toggle reveals the SDK's widget alongside the app's, so both can be compared live — both driven off the exact same `currentfloorchanged` event, so tapping either one keeps the other in sync. The app's native picker remains fully functional regardless of the toggle's state, which is the actual point being demonstrated.

## SDK usage

```js
// window.MapBridge, JS side — identical call already used by ui-part-visibility
setUIPartVisible: function (uiPart, isVisible) {
  if (!view) return;
  view.setUIPartVisible(uiPart, isVisible);
},
```

```swift
// Swift side — the same VisioOneBridge.setUIPartVisible(_:isVisible:) as
// ui-part-visibility (which also records the hidden parts, the SDK having no
// getter), called with the one part this feature cares about.
func setSdkFloorSelectorVisible(_ isVisible: Bool) {
    setUIPartVisible(.floorSelector, isVisible: isVisible)
}
var isSdkFloorSelectorVisible: Bool { !hiddenUIParts.contains(.floorSelector) }
```

`view.setUIPartVisible(uiPart: UIPart, isVisible: boolean): void` — one of the SDK's exact, case-sensitive `UIPart` values (`'floorSelector'` here); see [`ui-part-visibility`](./ui-part-visibility.md) for the full set and its pitfalls.

This feature reuses [`floor-selector`](./floor-selector.md)'s existing native picker verbatim rather than reimplementing it — same `view.goToFloor()`/`view.goToBuilding()` calls, same `venue.venueLayout.buildings` data, same `currentfloorchanged` listener keeping it in sync. The only thing added here is the one `setUIPartVisible` call (and the toggle to flip it live) that hides the SDK's own widget instead of leaving it to coexist, which is what `floor-selector` does by design.

## Things to know

- **Hiding the SDK's widget doesn't touch its underlying state.** `view.currentFloor`/`view.currentBuilding` and the `currentfloorchanged` event keep firing exactly the same whether or not the widget is drawn — `setUIPartVisible` is purely visual. The native picker's own sync logic (already built for `floor-selector`) needed zero changes to keep working with the SDK widget hidden.
- **The default here is the opposite of the SDK's own default.** Every `UIPart` (including `floorSelector`) is visible by default until `setUIPartVisible` is called — unlike `ui-part-visibility`, which leaves that default alone until a user flips a switch, this feature must proactively call `setUIPartVisible('floorSelector', false)` once `view` exists to establish "app's native picker only" as the starting state.
- Both pickers driving the same floor/building state live (each tap firing `currentfloorchanged`, which both sides listen to) means there is no risk of the two drifting out of sync while comparing them side by side with the toggle on.

## Learn more

- [`floor-selector`](./floor-selector.md) — the native picker this feature reuses.
- [`ui-part-visibility`](./ui-part-visibility.md) — the general 5-part `setUIPartVisible` toggle panel this feature specializes to one fixed part and one fixed intent (a permanent replacement, not an ad-hoc show/hide).
