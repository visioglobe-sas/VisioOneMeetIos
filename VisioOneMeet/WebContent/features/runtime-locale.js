// runtime-locale: reads and switches the map's displayed locale. Also used
// by add-locale ("Switch to Spanish"). See docs/features/runtime-locale.md.
(function (core) {
  core.register({
    // Reads the venue's current locale (venue.currentLocale: string,
    // readonly). A synchronous read of data the SDK already holds.
    getCurrentLocale: function () {
      if (!core.venue) return null;
      return core.venue.currentLocale;
    },
    // Switches the map's displayed locale via venue.setCurrentLocale(),
    // which re-renders every POI/label's text -- and any current View UI --
    // for the new locale on its own; no manual re-fetch of POI data is
    // needed here. Returns the SDK's own Promise directly so the native side
    // awaits the exact same settlement.
    setCurrentLocale: function (locale) {
      if (!core.venue) return Promise.reject(new Error('venue not loaded'));
      return core.venue.setCurrentLocale(locale);
    },
  });
})(window.MapCore);
