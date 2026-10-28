// dynamic-poi-crud: creates, edits the label text of, and removes a single
// POI at runtime. See docs/features/dynamic-poi-crud.md.
(function (core) {
  // The single dynamic POI/Label created by createDynamicPOI (both null when
  // none is tracked) -- kept here rather than passed back and forth across
  // the bridge, since POI/Label aren't JSON-serializable handles.
  var dynamicPoi = null;
  var dynamicLabel = null;

  core.onReset(function () {
    dynamicPoi = null;
    dynamicLabel = null;
  });

  core.register({
    // Creates a bare POI (id/floor/categories only -- a freshly created POI
    // has no visual footprint of its own) via venue.createPOI(), then
    // attaches a Label to it via venue.createLabel() so it's actually
    // visible on the map, copying its position from an existing "anchor" POI
    // (core.poiDisplayPosition; this demo has no "tap to place" UI). Returns
    // a discriminated result rather than letting an exception propagate, so
    // every outcome -- including venue.createPOI() throwing
    // POIAlreadyExistsError on a duplicate id -- is a normal state on the
    // native side, not a crash:
    //   { status: 'created', id }        on success
    //   { status: 'duplicate' }          id already used in the venue
    //   { status: 'anchorNotFound' }     anchorId doesn't resolve to a POI
    //   { status: 'noPosition' }         anchor POI has no position to copy
    createDynamicPOI: async function (newId, anchorId, labelText) {
      var venue = core.venue;
      if (!venue) return { status: 'anchorNotFound' };
      var anchor = core.findPoi(anchorId);
      if (!anchor) return { status: 'anchorNotFound' };
      var position = core.poiDisplayPosition(anchor);
      if (!position) return { status: 'noPosition' };

      var poi;
      try {
        poi = venue.createPOI({ id: newId });
      } catch (e) {
        return { status: 'duplicate' };
      }

      dynamicPoi = poi;
      dynamicLabel = venue.createLabel({
        poi: poi,
        position: position,
        width: 2,
        text: labelText,
      });

      return { status: 'created', id: poi.id };
    },
    // Updates the tracked dynamic POI's label text via venue.updateLabel() --
    // the real "edit a dynamic POI" story, since venue.updatePOI() itself can
    // only ever touch categories, never anything visual. No-op if nothing is
    // currently tracked.
    updateDynamicLabelText: function (text) {
      if (!core.venue || !dynamicLabel) return;
      core.venue.updateLabel(dynamicLabel, { text: text });
    },
    // Removes the tracked dynamic POI via venue.removePOI(), which cascades
    // to remove its attached label automatically -- no separate label
    // removal call is needed. No-op if nothing is currently tracked.
    removeDynamicPOI: function () {
      if (!core.venue || !dynamicPoi) return;
      core.venue.removePOI(dynamicPoi);
      dynamicPoi = null;
      dynamicLabel = null;
    },
  });
})(window.MapCore);
