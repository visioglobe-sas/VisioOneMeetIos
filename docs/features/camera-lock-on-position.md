# Camera Lock on Position

## Description

Locks the camera's focus on the currently tracked position, via `view.lockCameraPositionOnTracking` — a boolean `View` property, not a method. This depends entirely on a tracked position already being simulated/injected (see `docs/features/simulated-position.md`): with no moving tracked position, locking the camera onto it has no visible effect.

The SDK changes this property on its own (tracking on/off, user pans), so the demo's toggle doesn't keep its own value: it mirrors the SDK state, kept in sync through the `trackingon`, `trackingoff` and `trackingchanged` view events.

## SDK usage

Setting the lock (native -> JS):

```js
// VisioOneMeet/WebContent/features/camera-lock-on-position.js
setCameraLockOnPosition: function (locked) {
  if (!core.view) return;
  core.view.lockCameraPositionOnTracking = locked;
},
```

```swift
// VisioOneMeet/Features/CameraLockOnPosition/CameraLockOnPosition+Bridge.swift
func setCameraLockOnPosition(_ locked: Bool) {
    call("setCameraLockOnPosition", args: [locked])
}
```

Mirroring the lock state (JS -> native), subscribed once right after `createView`:

```js
// VisioOneMeet/WebContent/features/camera-lock-on-position.js
function sendCameraLockState() {
  var view = core.view;
  if (!view) return;
  // window.webkit.messageHandlers.mapBridge.postMessage({ type, message })
  core.sendToNative('cameraLockChanged', { locked: view.lockCameraPositionOnTracking === true });
}

core.onViewCreated(function (view) {
  ['trackingon', 'trackingoff', 'trackingchanged'].forEach(function (eventName) {
    view.addEventListener(eventName, sendCameraLockState);
  });
});
```

```swift
// VisioOneMeet/Features/CameraLockOnPosition/CameraLockOnPositionModel.swift
bridge.onMessage("cameraLockChanged") { [weak self] payload in
    guard let payload = payload as? [String: Any],
          let locked = payload["locked"] as? Bool else { return }
    self?.isCameraLockedOnPosition = locked   // @Published, drives the toggle
}
```

The toggle reads `isCameraLockedOnPosition` and, when the user flips it, only calls `setCameraLockOnPosition(newValue)`; the UI then follows the `trackingchanged` event.

## Things to know

- **`view.allowTracking = true` turns the lock on by itself.** Setting it always forces `lockCameraPositionOnTracking` (and `lockCameraOrientationOnTracking`) to `true` and fires `trackingon`. Right after tracking starts, the camera is already locked — a UI defaulting to "off" would be wrong.
- **`view.allowTracking = false` turns it off** (both locks back to `false`) and fires `trackingoff`.
- **A user pan/manipulation of the map while tracking turns the lock off**, done by the SDK itself, which fires `trackingchanged`.
- **Setting `lockCameraPositionOnTracking` fires `trackingchanged`** — but only on an actual change: the setter is a no-op if the value is unchanged, or if tracking isn't allowed (`allowTracking` is `false`). It never throws (unlike `view.injectTrackedPosition`, which throws if `allowTracking` is `false`).
- **The tracking events carry no lock value**: read `view.lockCameraPositionOnTracking` inside the handler. Subscribe to all three (`trackingon`, `trackingoff`, `trackingchanged`) to keep a UI in sync.
- **Don't re-set `view.allowTracking = true` on every position update** — it re-locks the camera each time, undoing the user's pan or your own unlock within one update. Only set it when it isn't already `true` (see `docs/features/simulated-position.md`).
- **The SDK also exposes `view.lockCameraOrientationOnTracking`** (locks the camera's *orientation* to device orientation-sensor data) — a separate property from position locking, not covered here.

## Learn more

- See `docs/features/simulated-position.md` for the tracked-position mechanism this locks onto.
