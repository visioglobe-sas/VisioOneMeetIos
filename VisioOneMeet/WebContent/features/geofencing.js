// geofencing: hands a zone POI's boundary to native, which runs its own
// point-in-polygon check against the position simulated by
// simulated-position.js (the SDK has no geofencing/containment primitive of
// its own), and colors that zone as the "inside" alert. See
// docs/features/geofencing.md.
(function (core) {
  core.register({
    // Returns a zone POI's boundary as a flat WGS84 polygon. Distinguishes
    // "POI doesn't exist" from "POI exists but has no usable surface
    // geometry" (no surfaces, or every surface's positions array has fewer
    // than 3 points) so the native side can show the right message; picks
    // the first surface with >= 3 points when a POI has several.
    resolveZonePolygon: function (poiId) {
      if (!core.venue) return { status: 'notFound' };
      var poi = core.findPoi(poiId);
      if (!poi) return { status: 'notFound' };
      var surface = (poi.surfaces || []).find(function (s) { return s.positions && s.positions.length >= 3; });
      if (!surface) return { status: 'noSurface' };
      return {
        status: 'ok',
        positions: surface.positions.map(function (p) { return { latitude: p.latitude, longitude: p.longitude }; }),
      };
    },
    // Colors/reverts a zone POI's surface(s) as the visual "you're inside
    // the geofence" alert (venue.updateSurface() + 'initial' to revert).
    // Called by the native side whenever its point-in-polygon check flips
    // the tracked position's inside/outside state.
    setZoneAlert: function (poiId, active) {
      var venue = core.venue;
      if (!venue) return;
      var poi = core.findPoi(poiId);
      if (!poi) return;
      poi.surfaces.forEach(function (surface) {
        venue.updateSurface(surface, { color: active ? '#E74C3C' : 'initial' });
      });
    },
  });
})(window.MapCore);
