// camera-lock-on-position: locks/unlocks the camera onto the tracked
// position (view.lockCameraPositionOnTracking) and mirrors that value to
// native ('cameraLockChanged'). The tracked position itself comes from
// simulated-position.js. See docs/features/camera-lock-on-position.md.
(function (core) {
  function sendCameraLockState() {
    var view = core.view;
    if (!view) return;
    core.sendToNative('cameraLockChanged', { locked: view.lockCameraPositionOnTracking === true });
  }

  // The SDK changes the lock on its own: allowTracking = true turns it on
  // ('trackingon'), allowTracking = false turns it off ('trackingoff'), and
  // a user pan while tracking turns it off ('trackingchanged', also fired by
  // our own setCameraLockOnPosition). None of these events carries the
  // value, so it's read off the view.
  core.onViewCreated(function (view) {
    ['trackingon', 'trackingoff', 'trackingchanged'].forEach(function (eventName) {
      view.addEventListener(eventName, sendCameraLockState);
    });
  });

  core.register({
    // Only has a visible effect once view.allowTracking is already true
    // (i.e. a tracked position is being injected) -- per the SDK's own doc
    // comment, setting this while tracking is off is a harmless no-op, not
    // an error, so no guard is needed here. The native toggle follows the
    // 'trackingchanged' event rather than keeping its own value.
    setCameraLockOnPosition: function (locked) {
      if (!core.view) return;
      core.view.lockCameraPositionOnTracking = locked;
    },
  });
})(window.MapCore);
