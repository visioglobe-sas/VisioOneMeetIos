# Reset View

## Description

Recenters the camera on the whole venue via `view.goToGlobal()` — a `View` method that takes no arguments and animates the camera back to the venue's default overview.

## SDK usage

```swift
// VisioOneMeet/Features/ResetView/ResetView+Bridge.swift
func goToGlobal() {
    call("goToGlobal")
}
```

```js
// VisioOneMeet/WebContent/features/reset-view.js
core.register({
  goToGlobal: function () {
    if (core.view) core.view.goToGlobal();
  },
});
```

`view` is the object returned once the promise from `visioOne.createView(container, venue)` resolves — keep a reference to it, since most `View` methods (including this one) are called on it directly.

## Things to know

- Takes no arguments — no JSON-encoding needed, unlike SDK calls that take structured data.
- `view` is `null` until `createView` resolves; calling `goToGlobal` before that is a silent no-op — no error, the camera simply doesn't move.
- The camera animates back immediately when called. The bridge call's completion (`callAsyncJavaScript`) only reports JS-execution errors, not animation completion — there's no callback or event to await for the animation itself.

## Learn more

- See `docs/features/goto-poi.md` for `view.goToFloor()`/`view.goToPOI()`, used together for a more targeted camera move than a full reset.
