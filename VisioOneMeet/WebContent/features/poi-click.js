// poi-click: forwards the SDK's `poiclick` event to native ('poiSelected'),
// so the app can react to a POI tap with a native panel. `event.pois` is the
// array of POIs under the tap point; only the topmost one is relevant here.
// See docs/features/poi-click.md.
(function (core) {
  core.onViewCreated(function (view) {
    view.addEventListener('poiclick', function (event) {
      var poi = event.pois && event.pois[0];
      if (!poi) return;
      core.sendToNative('poiSelected', {
        id: poi.id,
        name: poi.labels && poi.labels.length ? poi.labels[0].text : null,
      });
    });
  });
})(window.MapCore);
