// compute-navigation: computes a route between two POIs (by ID) and displays
// it (core.showNavigation: venue.computeNavigation() +
// venue.createNavigationTrace() + view.setCurrentNavigationTrace()). That
// last call replaces whatever route was previously current on its own, so no
// manual cleanup is needed between two calls. Also used by accessible-mode,
// whose `isAccessible` option is forwarded as-is. Errors thrown by
// computeNavigation (e.g. no route found) propagate to the Swift side rather
// than being caught here. See docs/features/compute-navigation.md.
(function (core) {
  core.register({
    computeNavigation: function (request) {
      core.showNavigation(request, undefined);
    },
  });
})(window.MapCore);
