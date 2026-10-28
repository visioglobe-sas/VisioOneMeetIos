// custom-data: reads a POI's business CustomData (free key/value strings
// such as price, opening hours, product reference), set in VisioMapEditor.
// See docs/features/custom-data.md.
(function (core) {
  core.register({
    // venue.refreshCustomData() is never called automatically on load -- the
    // cache starts empty ({}) until this resolves at least once, so it's
    // awaited here before every lookup. venue.getPOICustomData() is
    // synchronous and always returns an object (never null/undefined), {}
    // when the POI has no CustomData.
    //
    // refreshCustomData() rejects (rather than resolving) when the venue has
    // no CustomData published yet -- e.g. a 404 on its customData.json
    // surfaces here as an "Error: Hash not found" rejection. That's a normal
    // "nothing to load yet" outcome, not a real failure, so it's swallowed
    // here and the lookup proceeds against whatever the (possibly
    // still-empty) cache holds, rather than propagating as a failure to the
    // Swift side.
    loadCustomData: async function (poiId) {
      var venue = core.venue;
      if (!venue) return { found: false };
      try {
        await venue.refreshCustomData();
      } catch (e) {
        // Intentionally ignored -- see comment above.
      }
      var poi = core.findPoi(poiId);
      if (!poi) return { found: false };
      return { found: true, data: venue.getPOICustomData(poi) };
    },
  });
})(window.MapCore);
