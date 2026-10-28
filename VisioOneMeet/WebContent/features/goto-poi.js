// goto-poi: centers/zooms the camera on a POI by ID and highlights its
// surfaces. goToPOI is also used by 3d-icon-marker, custom-text-label and
// html-overlay-marker to bring the placed object on screen. See
// docs/features/goto-poi.md.
(function (core) {
  // Last POI targeted via goToPOI, so clearPOI knows which surfaces to reset.
  var selectedPoi = null;

  core.onReset(function () {
    selectedPoi = null;
  });

  core.register({
    goToPOI: function (poiId) {
      var venue = core.venue;
      var view = core.view;
      if (!venue || !view) return;
      var poi = core.findPoi(poiId);
      if (!poi) return;

      if (selectedPoi) {
        selectedPoi.surfaces.forEach(function (surface) {
          venue.updateSurface(surface, { selectionColor: undefined });
        });
      }
      selectedPoi = poi;
      poi.surfaces.forEach(function (surface) {
        venue.updateSurface(surface, { selectionColor: '#057DBC' });
      });

      // The SDK docs for goToPOI are explicit: the caller must switch floor
      // first, otherwise the currentFloor/Building stays whatever it was.
      var floorChange = poi.floor ? view.goToFloor(poi.floor) : Promise.resolve();
      floorChange.then(function () {
        view.goToPOI(poi, {
          orientation: { pitch: 20 },
          padding: { top: 100, bottom: 100, right: 100, left: 100 },
        });
      });
    },
    // Resets the highlight left by goToPOI. Does not move the camera back
    // (see docs/features/goto-poi.md for why "Clear" isn't also "Reset view").
    clearPOI: function () {
      var venue = core.venue;
      if (!venue || !selectedPoi) return;
      selectedPoi.surfaces.forEach(function (surface) {
        venue.updateSurface(surface, { selectionColor: undefined });
      });
      selectedPoi = null;
    },
  });
})(window.MapCore);
