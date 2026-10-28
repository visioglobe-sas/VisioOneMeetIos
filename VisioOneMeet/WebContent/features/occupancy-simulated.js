// occupancy-simulated: colors a POI's surface(s) with an occupancy color.
// The loop that cycles the colors is native (OccupancySimulatedModel), a
// stand-in for a real sensor feed. See docs/features/occupancy-simulated.md.
(function (core) {
  core.register({
    // Colors a POI's surface(s) with an occupancy color, or resets them to
    // the map's own color when `color` is null ('initial').
    updateOccupancy: function (poiId, color) {
      var venue = core.venue;
      var poi = core.findPoi(poiId);
      if (!poi) return;
      poi.surfaces.forEach(function (surface) {
        venue.updateSurface(surface, { color: color || 'initial' });
      });
    },
  });
})(window.MapCore);
