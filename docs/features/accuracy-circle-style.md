# Accuracy Circle Style

## Description

Recolors the precision (accuracy) circle around the tracked position while a position is being tracked, via `view.updatePositionTrackerGraphicOptions({ color, opacity })`. This builds on a tracked position being injected with `view.injectTrackedPosition()` (see `docs/features/simulated-position.md`). The circle's radius is set separately, on each inject, through `precisionCircleRadius`.

## SDK usage

```ts
view.updatePositionTrackerGraphicOptions(options: { color?: Color; opacity?: number }): void
view.injectTrackedPosition({ position, precisionCircleRadius }) // radius in meters
```

```js
// window.MapBridge, JS side
updatePositionTrackerGraphicOptions: function (color, opacity) {
  if (!view) return { status: 'error', message: 'view not ready' };
  try {
    view.updatePositionTrackerGraphicOptions({ color: color, opacity: opacity });
  } catch (e) {
    return { status: 'error', message: e && e.message ? e.message : String(e) };
  }
  return { status: 'applied' };
},
```

```swift
// Native side. callAsyncJavaScript passes the color string and the opacity
// number as real JS arguments, so nothing is hand-escaped.
webView.callAsyncJavaScript(
    "return window.MapBridge.updatePositionTrackerGraphicOptions(color, opacity);",
    arguments: ["color": "#e53935", "opacity": 0.5],
    in: nil,
    in: .page
) { result in /* { status: "applied" } or { status: "error", message } */ }
```

## Things to know

- **Only the precision circle is recolored, not the arrow in its center.** In SDK 1.1.0, `color`/`opacity` feed only the circle drawn with `precisionCircleRadius`; the tracked-position arrow at its center is a separate image that always keeps its default look. With no (or a `0`) radius there is nothing visible to recolor, despite the SDK typings describing the options as applying to "the dot and its precision circle".
- **The options are only stored, not drawn right away.** They take effect at the **next** `injectTrackedPosition` call. With a position feed that updates often (here, every ~150 ms), the change looks instant. If the position isn't updated, nothing changes on screen.
- **The SDK resets color and opacity to its defaults (`#0094f0`, `0.3`) whenever tracking stops** (`view.allowTracking = false`). Re-send your style each time tracking starts again, before or with the first `injectTrackedPosition`. You can call it while tracking is off: the stored options are used at the next inject.
- **The radius is not a graphic option.** It is `precisionCircleRadius` (in meters) on each `injectTrackedPosition` call. If it's omitted or `0`, no circle is drawn.
- **An invalid color throws.** Accepted formats are hex, `rgba()` and `hsl()`. A non-number opacity throws `"Blue dot's opacity must be a number."`. Opacity `0` skips that check because it's falsy, so this demo's opacity slider starts at `0.1`.
- **There is no getter for the current graphic options.** Track the selected color and opacity in your app. This demo keeps them outside the control panel, so they survive the panel being closed and reopened.

## Learn more

- `docs/features/simulated-position.md`: the `injectTrackedPosition` / `allowTracking` loop this styles.
