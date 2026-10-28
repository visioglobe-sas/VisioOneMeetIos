// custom-text-label: places free text on the map next to an anchor POI,
// restyles it live and removes it. See docs/features/custom-text-label.md.
(function (core) {
  // The single text Label placed by placeTextLabel (null when none), plus
  // the exact createLabel options it was created with -- Label isn't
  // JSON-serializable, and setTextLabelRotation needs those options to
  // recreate it (rotation isn't part of LabelUpdateOptions).
  var textLabel = null;
  var textLabelOptions = null;

  core.onReset(function () {
    textLabel = null;
    textLabelOptions = null;
  });

  // Shared by placeTextLabel/setTextLabelRotation: calls venue.createLabel
  // and stores the result + its options, or reports the SDK's error (e.g. an
  // invalid color format) as a normal result.
  function createTextLabel(options) {
    try {
      textLabel = core.venue.createLabel(options);
    } catch (e) {
      return { status: 'error', message: core.errorMessage(e) };
    }
    textLabelOptions = options;
    return { status: 'placed' };
  }

  function removeCurrentLabel() {
    core.venue.removeLabel(textLabel);
    textLabel = null;
    textLabelOptions = null;
  }

  core.register({
    // venue.createLabel(), owned by an existing "anchor" POI and positioned
    // at that POI's display position, offset by ~4 m so it doesn't overlap
    // the anchor's own map label. width/height are in meters; height is
    // ALWAYS passed explicitly (the SDK defaults it to width otherwise -- a
    // square box). Everything is validated first (text, anchor POI, anchor
    // position); only then is any text label already placed removed and the
    // new one created -- one at a time, and a failed place leaves the
    // existing label untouched. The anchor position never comes from our own
    // label (poiDisplayPosition's `exclude`). Returns a discriminated result
    // rather than throwing:
    //   { status: 'placed' }           on success
    //   { status: 'textRequired' }     text is empty after trimming
    //   { status: 'poiNotFound' }      anchorId doesn't resolve to a POI
    //   { status: 'noPosition' }       anchor POI has no position
    //   { status: 'error', message }   venue.createLabel threw
    placeTextLabel: async function (anchorId, text, color, width, height, rotation) {
      if (!core.venue) return { status: 'poiNotFound' };
      if (!text || !String(text).trim()) return { status: 'textRequired' };
      var anchor = core.findPoi(anchorId);
      if (!anchor) return { status: 'poiNotFound' };
      var anchorPosition = core.poiDisplayPosition(anchor, textLabel);
      if (!anchorPosition) return { status: 'noPosition' };

      if (textLabel) removeCurrentLabel();

      return createTextLabel({
        poi: anchor,
        position: core.offsetPosition(anchorPosition),
        width: width,
        height: height,
        text: text,
        color: color,
        rotation: rotation,
      });
    },
    // Restyles the placed text label in place via venue.updateLabel().
    // `options` is any subset of { text, color, width, height } -- width and
    // height are always sent together by the native side, since
    // updateLabel({ width }) alone also resets height to width. Never carries
    // rotation (not part of LabelUpdateOptions, see setTextLabelRotation).
    // Returns { status: 'updated' | 'noLabel' | 'textRequired' | 'error',
    // message? }.
    updateTextLabel: function (options) {
      if (!core.venue || !textLabel) return { status: 'noLabel' };
      if ('text' in options && (!options.text || !String(options.text).trim())) {
        return { status: 'textRequired' };
      }
      try {
        core.venue.updateLabel(textLabel, options);
      } catch (e) {
        return { status: 'error', message: core.errorMessage(e) };
      }
      Object.assign(textLabelOptions, options);
      return { status: 'updated' };
    },
    // rotation is only accepted by venue.createLabel(), so a rotation change
    // removes the label and recreates it with the same options + the new
    // rotation. No-op ({ status: 'noLabel' }) if nothing is placed.
    setTextLabelRotation: function (rotation) {
      if (!core.venue || !textLabel) return { status: 'noLabel' };
      var options = Object.assign({}, textLabelOptions, { rotation: rotation });
      removeCurrentLabel();
      return createTextLabel(options);
    },
    // Removes the placed text label via venue.removeLabel(); the anchor POI
    // and its own map label are untouched. No-op if nothing is placed (the
    // SDK itself throws "Provided label is not registered" on a double
    // remove).
    removeTextLabel: function () {
      if (!core.venue || !textLabel) return;
      removeCurrentLabel();
    },
  });
})(window.MapCore);
