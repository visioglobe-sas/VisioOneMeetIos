// custom-navigation-trace: restyles the route currently displayed
// (core.currentNavigationTrace, created by compute-navigation.js). See
// docs/features/custom-navigation-trace.md.
(function (core) {
  core.register({
    // venue.updateNavigationTrace(trace, options) -- colors only
    // (NavigationTraceUpdateOptions also has textureRepeat/animationSpeed,
    // relevant only to the 'textured' displayMode, which can't be changed
    // after createNavigationTrace()). No-op if no trace exists yet.
    //
    // venue.updateNavigationTrace() can throw an internal TypeError
    // ("Cannot read properties of undefined (reading 'material')") right
    // after a fresh trace is created, while still applying every color in
    // `options`. Caught here so it never surfaces as a script failure on
    // the Swift side.
    updateNavigationTrace: function (options) {
      if (!core.venue || !core.currentNavigationTrace) return;
      try {
        core.venue.updateNavigationTrace(core.currentNavigationTrace, options);
      } catch (error) {
        console.warn('[VisioOne:web] updateNavigationTrace threw (trace styling still applied):', error);
      }
    },
  });
})(window.MapCore);
