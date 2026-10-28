// 3d-icon-marker: places an image (an icon here) in the 3D scene, switches
// its orientation live and removes it. See docs/features/3d-icon-marker.md.
(function (core) {
  // Images created by placeIconImage, keyed by the id the native side chose
  // for them -- Image isn't JSON-serializable, so the native side only ever
  // holds the key.
  var iconImages = {};

  core.onReset(function () {
    iconImages = {};
  });

  core.register({
    // venue.createImage(), owned by an existing "anchor" POI and positioned
    // at that POI's display position (core.poiDisplayPosition, skipping the
    // icon this page already placed there). width/height are in meters; url
    // can be any image URL, including a data: URL. Any image already stored
    // under imageId is removed first, so a key never holds two images.
    // Returns a discriminated result rather than throwing:
    //   { status: 'placed', id }       on success
    //   { status: 'poiNotFound' }      anchorId doesn't resolve to a POI
    //   { status: 'noPosition' }       anchor POI has no position
    //   { status: 'error', message }   venue.createImage threw
    placeIconImage: async function (imageId, anchorId, url, orientationType) {
      var venue = core.venue;
      if (!venue) return { status: 'poiNotFound' };
      var anchor = core.findPoi(anchorId);
      if (!anchor) return { status: 'poiNotFound' };
      var position = core.poiDisplayPosition(anchor, iconImages[imageId]);
      if (!position) return { status: 'noPosition' };

      if (iconImages[imageId]) {
        venue.removeImage(iconImages[imageId]);
        delete iconImages[imageId];
      }

      try {
        iconImages[imageId] = venue.createImage({
          poi: anchor,
          position: position,
          width: 6,
          height: 6,
          url: url,
          orientationType: orientationType,
        });
      } catch (e) {
        return { status: 'error', message: core.errorMessage(e) };
      }
      return { status: 'placed', id: imageId };
    },
    // Switches an already-placed image's orientation live via
    // venue.updateImage() -- 'fixed' (flat on the ground, fixed heading),
    // 'flat' (flat on the ground, turning to face the camera) or 'facing'
    // (billboard, always facing the camera). No-op if nothing is stored
    // under imageId.
    updateIconImageOrientation: function (imageId, orientationType) {
      if (!core.venue || !iconImages[imageId]) return;
      core.venue.updateImage(iconImages[imageId], { orientationType: orientationType });
    },
    // Removes the image stored under imageId via venue.removeImage(); the
    // anchor POI itself is untouched. No-op if nothing is stored there.
    removeIconImage: function (imageId) {
      if (!core.venue || !iconImages[imageId]) return;
      core.venue.removeImage(iconImages[imageId]);
      delete iconImages[imageId];
    },
  });
})(window.MapCore);
