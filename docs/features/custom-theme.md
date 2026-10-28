# Custom theme

## Description

White-label styling beyond the defaults, applied live with no reload:

- **3D scene theme** — `view.themes` (read-only list of registered theme ids: `['day', 'night', 'goldenHour']` as of SDK 1.1.0) and `view.setTheme(name)`. A theme changes the scene's lighting (directional + ambient light color and position): `night` is bluish/darker, `goldenHour` warm/muted.
- **UI accent colors** — the settable `view.accentColor` / `view.textAccentColor` properties recolor the SDK's own UI buttons (POI card "Go", "Add a step", "Remove step"…): background and text respectively.

The theme choices are built at runtime from `view.themes`, not hardcoded. The SDK has no font option, so no custom font is demonstrated.

## SDK usage

The view must be created with `enableShadows: true`, otherwise `setTheme` has no visible effect (see "Things to know"). This screen passes `?enableShadows=1` to the page, which `MapCore.start()` turns into the `createView` option:

```js
// VisioOneMeet/WebContent/bridge/core.js
var viewOptions = {};
if (enableShadows) viewOptions.enableShadows = true;
// ... then visioOne.createView(container, venue, viewOptions)
```

```js
// VisioOneMeet/WebContent/features/custom-theme.js
core.register({
  // view.themes: readonly string[] -- synchronous read.
  getThemes: function () {
    if (!core.view) return [];
    return (core.view.themes || []).slice();
  },

  // view.setTheme(name: string): void -- throws on an unregistered id.
  setTheme: function (name) {
    if (!core.view) return { status: 'error', message: 'view not ready' };
    try {
      core.view.setTheme(name);
    } catch (e) {
      return { status: 'error', message: core.errorMessage(e) };
    }
    return { status: 'applied' };
  },

  // view.accentColor / view.textAccentColor: string (hex, rgba() or hsl()) --
  // throw on an invalid color. null leaves that color unchanged.
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
```

```swift
// VisioOneMeet/Features/CustomTheme/CustomTheme+Bridge.swift
extension VisioOneBridge {
    // ["day", "night", "goldenHour"], nil on a bridge failure.
    func getThemes() async -> [String]? {
        guard case .success(let value) = await callForResult("getThemes") else { return nil }
        return value as? [String]
    }

    // .success, or .sdkError(message) for an unregistered id.
    func setTheme(_ name: String) async -> BridgeResult {
        await callForStatus("setTheme", args: [name])
    }

    // nil leaves that color alone; a non-success outcome is logged.
    func setAccentColors(accent: String?, text: String?) {
        callReportingStatus("setAccentColors", args: [accent, text])
    }
}
```

The SDK has no current-theme getter, so `CustomThemeModel` (`VisioOneMeet/Features/CustomTheme/CustomThemeModel.swift`) tracks the applied theme and colors, and rolls the theme back when `setTheme` doesn't return `.success`.

Defaults (what a "reset" sends back): theme `day`, accent `#0094F0`, text accent `#FFFFFF`.

## Things to know

- **`setTheme` needs `enableShadows: true`.** Themes only change the scene lights, which are only rendered when the view is created with `createView(container, venue, { enableShadows: true })` (and a quality preset that allows shadows — `medium`, the default, or `high`; `low` disables them). Without it, switching theme is pixel-identical. Shadows are computationally expensive (per the SDK docs), so enable them only where you need themes.
- **Observed on the iOS Simulator, unverified on a physical device:** in the iOS Simulator's `WKWebView`, switching theme shows no visible change even with `enableShadows: true` (the option does reach the SDK), whereas desktop Chromium and desktop WebKit (Safari engine, Apple GPU) clearly show it.
- `setTheme('unknown')` throws `Cannot apply given theme unknown as it isn't registered.` — only pass ids read from `view.themes`.
- There is **no getter for the current theme** (as of SDK 1.1.0): track it on your side (the SDK starts on `day`).
- Switching back to `day` after another theme does not render pixel-identical to the freshly loaded view (lighting/shadows differ slightly); it's still the `day` theme.
- `setTheme` never touches the UI, and the accent colors never touch the 3D scene. The accent colors also don't change the surface selection color — that's the separate `view.surfaceSelectionColor`.
- An invalid color throws `Invalid color format provided, it should be hex color, rgba color or hsl color.`
- Accent colors apply live, including to a POI card already open.

## Learn more

- Both accent colors can also be set at load time through the page URL parameters `accentColor` / `textAccentColor` (SDK `URLParameters`), e.g. `map.html?accentColor=E53935&textAccentColor=FFEB3B` (the page URL) — hex values go **without** the `#` (the SDK prepends it); `rgb(...)`, `rgba(...)` and `hsl(...)` are passed as-is.
