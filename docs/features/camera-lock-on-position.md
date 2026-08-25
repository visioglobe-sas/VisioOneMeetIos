# Camera Lock on Position

## Description

Locks the camera's focus on the currently tracked position, via `view.lockCameraPositionOnTracking` — a boolean `View` property, not a method. This depends entirely on a tracked position already being simulated/injected (see `docs/features/simulated-position.md`): with no moving tracked position, locking the camera onto it has no visible effect.

## SDK usage

```js
// window.MapBridge, JS side
setCameraLockOnPosition: function (locked) {
  if (!view) return;
  view.lockCameraPositionOnTracking = locked;
},
```

```swift
func setCameraLockOnPosition(_ locked: Bool) {
    webView?.evaluateJavaScript("window.MapBridge.setCameraLockOnPosition(\(locked))")
}
```

## Things to know

- **`lockCameraPositionOnTracking` only has a visible effect once `view.allowTracking` is already `true`** — i.e., once a position is actually being tracked. Setting it before that is documented by the SDK as a silent no-op, **not** an exception (unlike `view.injectTrackedPosition`, which throws if `allowTracking` is `false`) — no guard is needed on either side of the bridge.
- **The SDK also exposes `view.lockCameraOrientationOnTracking`** (locks the camera's *orientation* to device orientation-sensor data) — a separate property from position locking, not covered here.
- It's a plain boolean property assignment, not a method call with arguments — the boolean is interpolated directly into the JS call, no JSON-encoding needed.
- Setting `view.allowTracking = false` (see `docs/features/simulated-position.md`) implicitly clears any effect of `lockCameraPositionOnTracking`, since there's no longer a tracked position to lock onto.

## Learn more

- See `docs/features/simulated-position.md` for the tracked-position mechanism this locks onto.
- `view.lockCameraOrientationOnTracking` is not covered here.
