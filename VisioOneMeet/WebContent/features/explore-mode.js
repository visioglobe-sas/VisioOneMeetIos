// explore-mode: the building-exploration mode ('global' | 'building' |
// 'floor'), set via view.currentExploreMode and mirrored to native
// ('exploreModeChanged'). See docs/features/explore-mode.md.
(function (core) {
  // JS -> native: pushes the current building-exploration mode. Sent once
  // after createView, then again on every `exploremodechanged` event --
  // including changes triggered by direct camera/map interaction, not just
  // the setExploreMode command below (e.g. moving the camera in/out of a
  // building in 'global' mode, or a click while in 'building' mode
  // auto-switching the SDK to 'floor').
  function sendExploreModeState() {
    var view = core.view;
    if (!view) return;
    core.sendToNative('exploreModeChanged', { currentExploreMode: view.currentExploreMode });
  }

  core.onViewCreated(function (view) {
    view.addEventListener('exploremodechanged', sendExploreModeState);
  });
  core.onReady(sendExploreModeState);

  core.register({
    // The resulting exploremodechanged event (listened to above) is what
    // actually pushes the new state back to native -- not this call itself
    // -- since the SDK can also change mode on its own.
    setExploreMode: function (mode) {
      if (!core.view) return;
      core.view.currentExploreMode = mode;
    },
  });
})(window.MapCore);
