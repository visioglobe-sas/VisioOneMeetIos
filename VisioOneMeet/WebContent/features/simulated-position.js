// simulated-position: resolves a POI's position, then injects/removes a
// simulated tracked position + accuracy circle. The loop that moves it is
// native (PositionTrackingController), a stand-in for a real indoor
// positioning feed; the other tracking screens (camera-lock-on-position,
// geofencing, accuracy-circle-style) reuse these three commands. See
// docs/features/simulated-position.md.
(function (core) {
  core.register({
    // Resolves a POI's WGS84 display position by ID (core.poiDisplayPosition:
    // label, else image/marker, else surface centroid). Returns null for an
    // unknown POI id or one with none of those -- both are "POI not found"
    // to the native caller.
    resolvePoiPosition: function (poiId) {
      var poi = core.findPoi(poiId);
      if (!poi) return null;
      var position = core.poiDisplayPosition(poi);
      if (!position) return null;
      return { latitude: position.latitude, longitude: position.longitude };
    },
    // Injects/updates the simulated tracked position + accuracy circle.
    // allowTracking must be true before the first injectTrackedPosition
    // call, so it's turned on here on the first call rather than requiring
    // a separate "start" step -- but ONLY on the false -> true transition:
    // setting allowTracking = true always forces lockCameraPositionOnTracking
    // (and the orientation lock) back to true, so re-setting it on every
    // ~150 ms tick would undo a user unlock (toggle or map pan) almost
    // immediately.
    injectTrackedPosition: function (latitude, longitude, precisionCircleRadius) {
      var view = core.view;
      if (!view) return;
      if (!view.allowTracking) {
        view.allowTracking = true;
      }
      view.injectTrackedPosition({
        position: { latitude: latitude, longitude: longitude },
        precisionCircleRadius: precisionCircleRadius,
      });
    },
    // Removes the simulated marker/accuracy circle. The SDK has no dedicated
    // stop method -- this is what allowTracking = false is for.
    stopTrackedPosition: function () {
      if (!core.view) return;
      core.view.allowTracking = false;
    },
  });
})(window.MapCore);
