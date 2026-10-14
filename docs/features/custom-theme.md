# Custom theme

## Description

White-label styling beyond the defaults, applied live with no reload:

- **3D scene theme** — `view.themes` (read-only list of registered theme ids: `['day', 'night', 'goldenHour']` on SDK 1.0.9) and `view.setTheme(name)`. A theme changes the scene's lighting (directional + ambient light color and position): `night` is bluish/darker, `goldenHour` warm/muted.
- **UI accent colors** — the settable `view.accentColor` / `view.textAccentColor` properties recolor the SDK's own UI buttons (POI card "Go", "Add a step", "Remove step"…): background and text respectively.

The theme choices are built at runtime from `view.themes`, not hardcoded. The SDK has no font option, so no custom font is demonstrated.

## SDK usage

The view must be created with `enableShadows: true`, otherwise `setTheme` has no visible effect (see "Things to know"):

```js
visioOne.loadVenue({ vg_maphash: hash }, container)
  .then(function (venue) {
    return visioOne.createView(container, venue, { enableShadows: true });
  });
```

JS side (`window.MapBridge`, in the page hosting the SDK):

```js
// view.themes: readonly string[] -- synchronous read.
getThemes: function () {
  return (view.themes || []).slice();
},

// view.setTheme(name: string): void -- throws on an unregistered id.
setTheme: function (name) {
  try {
    view.setTheme(name);
  } catch (e) {
    return { status: 'error', message: e.message };
  }
  return { status: 'applied' };
},

// view.accentColor / view.textAccentColor: string (hex, rgba() or hsl()) --
// throw on an invalid color. null leaves that color unchanged.
setAccentColors: function (accentColor, textAccentColor) {
  try {
    if (accentColor != null) view.accentColor = accentColor;
    if (textAccentColor != null) view.textAccentColor = textAccentColor;
  } catch (e) {
    return { status: 'error', message: e.message };
  }
  return { status: 'applied' };
},
```

Native side (Swift, `WKWebView`):

```swift
// Read the theme list (synchronous JS value).
webView.evaluateJavaScript("window.MapBridge.getThemes()") { result, _ in
    let themes = result as? [String] ?? []   // ["day", "night", "goldenHour"]
}

// Switch theme.
webView.callAsyncJavaScript(
    "return window.MapBridge.setTheme(name);",
    arguments: ["name": "night"], in: nil, in: .page
) { result in /* { status: "applied" } or { status: "error", message } */ }

// Recolor the SDK buttons.
webView.callAsyncJavaScript(
    "return window.MapBridge.setAccentColors(accent, text);",
    arguments: ["accent": "#E53935", "text": "#FFEB3B"], in: nil, in: .page
) { _ in }
```

Defaults (what a "reset" sends back): theme `day`, accent `#0094F0`, text accent `#FFFFFF`.

## Things to know

- **`setTheme` needs `enableShadows: true`.** Themes only change the scene lights, which are only rendered when the view is created with `createView(container, venue, { enableShadows: true })` (and a quality preset that allows shadows — `medium`, the default, or `high`; `low` disables them). Without it, switching theme is pixel-identical. Shadows are computationally expensive (per the SDK docs), so enable them only where you need themes.
- **Observed on the iOS Simulator, unverified on a physical device:** in the iOS Simulator's `WKWebView`, switching theme shows no visible change even with `enableShadows: true` (the option does reach the SDK), whereas desktop Chromium and desktop WebKit (Safari engine, Apple GPU) clearly show it.
- `setTheme('unknown')` throws `Cannot apply given theme unknown as it isn't registered.` — only pass ids read from `view.themes`.
- There is **no getter for the current theme** in SDK 1.0.9: track it on your side (the SDK starts on `day`).
- Switching back to `day` after another theme does not render pixel-identical to the freshly loaded view (lighting/shadows differ slightly); it's still the `day` theme.
- `setTheme` never touches the UI, and the accent colors never touch the 3D scene. The accent colors also don't change the surface selection color — that's the separate `view.surfaceSelectionColor`.
- An invalid color throws `Invalid color format provided, it should be hex color, rgba color or hsl color.`
- Accent colors apply live, including to a POI card already open.

## Learn more

- Both accent colors can also be set at load time through the page URL parameters `accentColor` / `textAccentColor` (SDK `URLParameters`), e.g. `map.html?accentColor=E53935&textAccentColor=FFEB3B` — hex values go **without** the `#` (the SDK prepends it); `rgb(...)`, `rgba(...)` and `hsl(...)` are passed as-is.
