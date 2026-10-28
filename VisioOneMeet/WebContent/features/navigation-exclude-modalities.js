// navigation-exclude-modalities: computes a route like compute-navigation.js,
// but additionally excludes one or more segment "particularities" (e.g.
// elevators, stairs) via venue.computeNavigation()'s excludedAttributes
// option, and clears the displayed route (also used by accessible-mode). On
// this app's demo map, an elevator hop's attribute is 'lift', not
// 'elevator'. See docs/features/navigation-exclude-modalities.md.
(function (core) {
  core.register({
    // Errors (e.g. no route survives the exclusion) propagate to the Swift
    // side, same as computeNavigation.
    computeNavigationExcludingModalities: function (request) {
      core.showNavigation(request, request.excludedAttributes);
    },
    // Clears whatever route is currently displayed via
    // view.removeCurrentNavigationTrace(). That call throws when nothing is
    // currently running -- caught here and swallowed, since "nothing to
    // clear" is a normal state, not a bridge failure.
    clearNavigationTrace: function () {
      if (!core.view) return;
      try {
        core.view.removeCurrentNavigationTrace();
      } catch (error) {
        console.warn('[VisioOne:web] removeCurrentNavigationTrace threw (nothing to clear):', error);
      }
      core.currentNavigationTrace = null;
    },
  });
})(window.MapCore);
