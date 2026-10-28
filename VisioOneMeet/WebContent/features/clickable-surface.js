// clickable-surface: makes a POI's surface(s) clickable via
// venue.updateSurface()'s isInteractive option -- the SDK itself then
// handles the hover/tap color swap (hoverColor/selectionColor), no click
// listener needed on either side of the bridge for that part. Disabling
// resets the base color to 'initial' so the surface doesn't stay stuck on
// the custom color set here. See docs/features/clickable-surface.md.
(function (core) {
  core.register({
    setSurfaceInteractive: function (poiId, isInteractive) {
      var venue = core.venue;
      if (!venue) return;
      var poi = core.findPoi(poiId);
      if (!poi) return;
      poi.surfaces.forEach(function (surface) {
        venue.updateSurface(
          surface,
          isInteractive
            ? { isInteractive: true, color: '#2ECC71', hoverColor: '#F1C40F', selectionColor: '#E74C3C' }
            : { isInteractive: false, color: 'initial' }
        );
      });
    },
  });
})(window.MapCore);
