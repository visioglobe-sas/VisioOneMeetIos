// html-overlay-marker: pins an interactive HTML badge on the map next to an
// anchor POI; taps on it are forwarded to native ('htmlBadgeTapped'). See
// docs/features/html-overlay-marker.md.
(function (core) {
  // The single HTML marker placed by placeHtmlBadge (null when none). Its
  // DOM element is reachable as htmlBadge.element; neither crosses the
  // bridge.
  var htmlBadge = null;
  var HTML_BADGE_STYLE =
    'background:#0B6BCB;color:#FFFFFF;font:600 14px sans-serif;padding:6px 12px;' +
    'border-radius:14px;white-space:nowrap;box-shadow:0 2px 6px rgba(0,0,0,.3);cursor:pointer';

  core.onReset(function () {
    htmlBadge = null;
  });

  core.register({
    // venue.createMarker({ poi, position, element }), owned by an existing
    // "anchor" POI and positioned ~4 m off that POI's display position
    // (excluding our own badge marker), same offset as custom-text-label.
    // Unlike a Label/Image, the element lives in the DOM above the 3D scene:
    // always facing the screen, never hidden by geometry, and tappable.
    // Validates everything first; only then is any badge already placed
    // removed and the new one created -- a failed place leaves the existing
    // badge untouched. Returns:
    //   { status: 'placed' }           on success
    //   { status: 'textRequired' }     text is empty after trimming
    //   { status: 'poiNotFound' }      anchorId doesn't resolve to a POI
    //   { status: 'noPosition' }       anchor POI has no position
    //   { status: 'error', message }   venue.createMarker threw
    placeHtmlBadge: async function (anchorId, text) {
      var venue = core.venue;
      if (!venue) return { status: 'poiNotFound' };
      if (!text || !String(text).trim()) return { status: 'textRequired' };
      var anchor = core.findPoi(anchorId);
      if (!anchor) return { status: 'poiNotFound' };
      var anchorPosition = core.poiDisplayPosition(anchor, htmlBadge);
      if (!anchorPosition) return { status: 'noPosition' };

      if (htmlBadge) {
        venue.removeMarker(htmlBadge);
        htmlBadge = null;
      }

      // Only content styling here: the SDK owns position/top/left/
      // translate/transform/z-index on this element.
      var element = document.createElement('div');
      element.setAttribute('style', HTML_BADGE_STYLE);
      element.textContent = text;

      try {
        htmlBadge = venue.createMarker({
          poi: anchor,
          position: core.offsetPosition(anchorPosition),
          element: element,
        });
      } catch (e) {
        return { status: 'error', message: core.errorMessage(e) };
      }
      // createMarker forces pointer-events:none on the element (taps would
      // fall through to the map); it doesn't rewrite it afterwards.
      element.style.pointerEvents = 'auto';
      element.addEventListener('click', function (event) {
        // Keep the tap from reaching the map (it would open the POI card of
        // whatever is underneath).
        event.stopPropagation();
        core.sendToNative('htmlBadgeTapped');
      });
      return { status: 'placed' };
    },
    // Changes the badge text with a plain DOM edit on the marker's live
    // element -- no SDK call involved. Returns { status: 'updated' |
    // 'noBadge' | 'textRequired' }.
    updateHtmlBadgeText: function (text) {
      if (!htmlBadge) return { status: 'noBadge' };
      if (!text || !String(text).trim()) return { status: 'textRequired' };
      htmlBadge.element.textContent = text;
      return { status: 'updated' };
    },
    // Shows/hides the badge via venue.updateMarker(marker, { isVisible })
    // (the element stays in the DOM, display:none). Returns { status:
    // 'updated' | 'noBadge' }.
    setHtmlBadgeVisible: function (isVisible) {
      if (!core.venue || !htmlBadge) return { status: 'noBadge' };
      core.venue.updateMarker(htmlBadge, { isVisible: isVisible });
      return { status: 'updated' };
    },
    // Removes the badge via venue.removeMarker(), which also detaches its
    // element from the DOM. No-op if nothing is placed (the SDK throws
    // "Provided marker is not registered" on a double remove).
    removeHtmlBadge: function () {
      if (!core.venue || !htmlBadge) return;
      core.venue.removeMarker(htmlBadge);
      htmlBadge = null;
    },
  });
})(window.MapCore);
