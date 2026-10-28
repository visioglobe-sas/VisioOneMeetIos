// ui-part-visibility: shows/hides one of the SDK's own default UI overlays
// via view.setUIPartVisible(). uiPart is one of exactly 5 case-sensitive
// string values ('floorSelector', 'navigation', 'poiDetails', 'search',
// 'userTracking') -- no validation here, an unknown value is simply ignored
// by the SDK. Also used by native-ui-replacement. See
// docs/features/ui-part-visibility.md.
(function (core) {
  core.register({
    setUIPartVisible: function (uiPart, isVisible) {
      if (!core.view) return;
      core.view.setUIPartVisible(uiPart, isVisible);
    },
  });
})(window.MapCore);
