// add-locale: adds a brand-new locale at runtime and reads values back. See
// docs/features/add-locale.md.
(function (core) {
  core.register({
    // Adds a locale via venue.translator.addLocale() -- one never authored
    // in VisioMapEditor for this map. This is backed by a generic i18next
    // resource bundle, entirely separate from the venue's own
    // POI/floor/building/category translation data (parsed once at load
    // from the published map's own JSON). It can never add or change a
    // POI/label/floor/building name -- only the SDK's own predefined
    // UI/navigation strings (when resources happens to include one of those
    // keys) and any custom, app-defined key. Synchronous, like translate
    // below -- no promise involved.
    addLocale: function (locale, resources) {
      if (!core.venue) return;
      core.venue.translator.addLocale(locale, resources);
    },
    // Reads a value back via venue.translator.translate() -- the reliable
    // way to prove addLocale worked, independent of whether any of the
    // SDK's own default UI parts happen to be visible.
    translate: function (key, locale) {
      if (!core.venue) return '';
      return core.venue.translator.translate(key, locale);
    },
  });
})(window.MapCore);
