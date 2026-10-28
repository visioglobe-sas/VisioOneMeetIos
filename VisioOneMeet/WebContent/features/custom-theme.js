// custom-theme: switches the 3D scene lighting theme and recolors the SDK's
// own UI buttons. The view of this screen is created with
// enableShadows: true (see core.js), without which themes have no visible
// effect. See docs/features/custom-theme.md.
(function (core) {
  core.register({
    // Reads the scene themes registered on the view (view.themes, a
    // read-only string array -- ['day', 'night', 'goldenHour'] as of SDK
    // 1.1.0). Synchronous.
    getThemes: function () {
      if (!core.view) return [];
      return (core.view.themes || []).slice();
    },
    // Switches the 3D scene lighting via view.setTheme(name). Throws on an
    // id not in view.themes, reported here as a normal result. Returns
    // { status: 'applied' | 'error', message? }.
    setTheme: function (name) {
      if (!core.view) return { status: 'error', message: 'view not ready' };
      try {
        core.view.setTheme(name);
      } catch (e) {
        return { status: 'error', message: core.errorMessage(e) };
      }
      return { status: 'applied' };
    },
    // Recolors the SDK's own UI buttons (POI card "Go", "Add a step"...)
    // live via the settable view.accentColor / view.textAccentColor
    // properties. Either argument may be null to leave that color alone.
    // Invalid colors throw, reported as a normal result. Returns
    // { status: 'applied' | 'error', message? }.
    setAccentColors: function (accentColor, textAccentColor) {
      var view = core.view;
      if (!view) return { status: 'error', message: 'view not ready' };
      try {
        if (accentColor != null) view.accentColor = accentColor;
        if (textAccentColor != null) view.textAccentColor = textAccentColor;
      } catch (e) {
        return { status: 'error', message: core.errorMessage(e) };
      }
      return { status: 'applied' };
    },
  });
})(window.MapCore);
