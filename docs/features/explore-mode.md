# Explore Mode

## Description

Drives the SDK's 3 building-exploration modes via `view.currentExploreMode`, and keeps a native segmented control in sync with the SDK's own state via the `exploremodechanged` event. "Building" mode is the flagship visual effect: every opened building's floors shown exploded, cross-section style — a "wahou effect" for sales demos, giving an immediate read of a multi-floor building's structure.

## SDK usage

```js
// window.MapBridge, JS side

setExploreMode: function (mode) {
  if (!view) return;
  view.currentExploreMode = mode; // 'global' | 'building' | 'floor'
},
```

```js
// Pushed once after createView, and again on every subsequent change --
// including changes triggered by direct camera/map interaction, not just
// the setExploreMode command above (e.g. moving the camera into a building
// while in 'global' mode, or a click auto-switching 'building' to 'floor').
view.addEventListener('exploremodechanged', function (event) {
  sendToNative('exploreModeChanged', { currentExploreMode: event.currentExploreMode });
});
```

`view.currentExploreMode` is a settable property of type `ExploreMode = 'global' | 'building' | 'floor'`. `setExploreMode` on the native side follows the same JSON-encoding-free pattern as other enum-backed calls in this bridge (a plain, non-user-supplied string interpolated directly into the generated script — see `VisioOneBridge.setExploreMode`).

The `exploremodechanged` event fires with an `ExploreModeEvent` payload; `event.currentExploreMode` carries the new mode directly, so the JS side never needs to re-read `view.currentExploreMode` separately inside the handler.

## Things to know

- **The 3 modes' semantics differ meaningfully, not just visually**:
  - `'global'` — the normal outside view. Moving the camera into or out of a building opens or closes it; when already on a specific floor, moving the camera outside that floor closes the building.
  - `'building'` — the outside is hidden, and every currently opened building is presented as an exploded "carousel" view (its floors spread out, cross-section style). The active floor within a building can be picked with the mouse wheel or by sliding the pointer up/down on the screen.
  - `'floor'` — only the "current" floor is displayed; a UI element lets the user go back to `'building'` mode.
- **A click in `'building'` mode auto-switches to `'floor'` mode** — this transition happens entirely inside the SDK, not via a second `setExploreMode` call from the app. It's the reason the native UI can't just optimistically mirror whatever the last tap requested: it must listen to `exploremodechanged` and reflect whatever mode the SDK actually lands on, exactly like `floor-selector`'s `currentfloorchanged` listener keeps that feature's native picker in sync with the SDK's own default widget (see `docs/features/floor-selector.md`).
- **`currentExploreMode` defaults to `'global'`** immediately after `createView` resolves — before anything has been opened, so `'building'` mode has nothing to explode yet.
- **Switching straight to `'building'` mode with no building currently opened still works**: the SDK opens the venue's first building automatically rather than showing an empty carousel, so this feature's control never needs a "which building" precondition.
- **There is no `currentbuildingchanged`/separate event for explore-mode changes triggered by `goToBuilding`/`goToFloor`** — those calls change `currentExploreMode` as a side effect (e.g. `goToFloor` implies `'floor'` mode), and that side effect is still reported through this same `exploremodechanged` event, not a different one.

## Learn more

- See `docs/features/floor-selector.md` for the sibling feature this one borrows its "keep a native control's active state in sync with an SDK event, since the SDK can change that state on its own" idiom from, and for `view.goToFloor()`/`view.goToBuilding()`, the calls that implicitly move `currentExploreMode` between `'building'` and `'floor'`.
