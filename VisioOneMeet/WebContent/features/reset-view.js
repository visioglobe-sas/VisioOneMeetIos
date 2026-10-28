// reset-view: recenters the camera on the whole venue via view.goToGlobal().
// See docs/features/reset-view.md.
(function (core) {
  core.register({
    goToGlobal: function () {
      if (core.view) core.view.goToGlobal();
    },
  });
})(window.MapCore);
