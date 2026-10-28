// accuracy-circle-style: recolors the tracked position's precision circle
// (not its arrow). The tracked position itself comes from
// simulated-position.js. See docs/features/accuracy-circle-style.md.
(function (core) {
  core.register({
    // view.updatePositionTrackerGraphicOptions({ color, opacity }). The SDK
    // only stores these options: they're drawn at the next
    // injectTrackedPosition call (the simulated-position loop makes that look
    // live), and they're reset to the SDK defaults (#0094f0, 0.3) every time
    // tracking stops (allowTracking = false), so the native side re-applies
    // them on each Start. Invalid colors / a non-number opacity throw,
    // reported as a normal result. Returns { status: 'applied' | 'error',
    // message? }.
    updatePositionTrackerGraphicOptions: function (color, opacity) {
      if (!core.view) return { status: 'error', message: 'view not ready' };
      try {
        core.view.updatePositionTrackerGraphicOptions({ color: color, opacity: opacity });
      } catch (e) {
        return { status: 'error', message: core.errorMessage(e) };
      }
      return { status: 'applied' };
    },
  });
})(window.MapCore);
