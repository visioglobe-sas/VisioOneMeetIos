# Add Locale

## Description

Adds a brand-new locale to the SDK **at runtime** — `'es'` (Spanish), never authored in VisioMapEditor for this map — via `venue.translator.addLocale(locale, resources)`, then reads the added values back via `venue.translator.translate(key, locale)` to prove the round trip worked. `resources` is a flat `{ [key: string]: string }` map; it includes one of the SDK's own predefined UI keys (`'search-for-anything'`) to show `addLocale` can override the SDK's own built-in UI text, and one custom, app-defined key (`'welcome-message'`) to show this is a general-purpose i18n store, usable for the app's own strings too.

## SDK usage

```js
// window.MapBridge, JS side
addLocale: function (locale, resources) {
  if (!venue) return;
  venue.translator.addLocale(locale, resources);
},
translate: function (key, locale) {
  if (!venue) return '';
  return venue.translator.translate(key, locale);
},
```

```swift
/// Adds the 'es' locale via venue.translator.addLocale(), then reads
/// addLocaleKeys back via translate(_:) to populate spanishTranslations.
func addSpanishLocale() async {
    guard let webView else { return }
    // ... JSON-encodes spanishResources, then:
    let didAdd: Bool = await withCheckedContinuation { continuation in
        webView.evaluateJavaScript("window.MapBridge.addLocale('es', \(resourcesJson))") { _, error in
            // ... continuation.resume(returning: error == nil)
        }
    }
    guard didAdd else { return }
    var results: [String: String] = [:]
    for key in Self.addLocaleKeys {
        results[key] = await translateSpanish(key)
    }
    spanishTranslations = results
}

private func translateSpanish(_ key: String) async -> String {
    guard let webView else { return "" }
    // ... JSON-encodes key, then:
    return await withCheckedContinuation { continuation in
        webView.evaluateJavaScript("window.MapBridge.translate(\(json), 'es')") { result, error in
            // ... continuation.resume(returning: result as? String ?? "")
        }
    }
}
```

`venue.translator.addLocale(locale: string, resources: Resources): void` and `venue.translator.translate(key: string, locale: string, context?: Context): string` are both **synchronous** — no `Promise` is returned by either, unlike `venue.setCurrentLocale()` (see `runtime-locale.md`). `addSpanishLocale()` is still declared `async` on the Swift side purely to sequence its own two `evaluateJavaScript` round trips (add, then read back), not because either SDK call itself is asynchronous.

The fixed dictionary passed to `addLocale` here is:

```js
{
  'search-for-anything': 'Busca lo que quieras',   // predefined SDK UI key
  'welcome-message': '¡Bienvenido a VisioOne!'      // custom, app-defined key
}
```

## Things to know

- **`addLocale` can never add or change a POI/label/floor/building name.** It is backed by a generic [i18next](https://www.i18next.com/) resource bundle, completely separate from the venue's own POI/floor/building/category translation data — which is parsed once at load from the published map's own JSON and exposed via `translatePOI`/`translateFloor`/`translateBuilding`/`translateCategory`. `addLocale` only affects (a) the SDK's own predefined UI/navigation strings, if the `resources` object happens to include one of those keys, and (b) any arbitrary custom key the calling app defines and later reads back via `translate`. Confirmed live with a standalone `WKWebView` harness loading this exact `map.html` + the vendored SDK bundle: a named POI's `venue.translator.translatePOI(poi, 'es').name` read the same real label text (`"Visio Mall Avenue"`, falling back to French/default) both immediately before and immediately after calling `addLocale('es', {...})` — completely unaffected by the call. This still holds after `setCurrentLocale('es')` makes the locale "live": `venue.currentLocale` reports `'es'`, but POI/label names keep falling back to `'default'`, since this map only has `default`/`en`/`fr` authored (see `runtime-locale.md`).
- **A runtime-added locale is not listed by `venue.translator.allLocales` afterwards.** Confirmed live on this app's shared demo map: `allLocales` reads `["en","fr"]` both before and after a successful `addLocale('es', {...})` call — `'es'` never appears in it, even though `translate('search-for-anything', 'es')` and `getLocale('es')` both work correctly right after. Don't use `allLocales` to detect whether a runtime-added locale exists; it only reflects locales published with the map.
- **The predefined keys `addLocale` can override are listed in its own TSDoc** in the SDK's `Translator.ts` — UI keys (`'search-for-anything'`, `'go'`, `'cancel'`, `'start'`, `'close'`, day-of-week names, etc.) and Navigation keys (`'turnRight'`, `'changeFloor'`, `'goStraight'`, etc.). Any other key is just as valid to pass — `resources` is a fully generic key/value store, not restricted to that list.
- **`translate(key, locale)` for a key that was never added falls back to returning the key itself** (i18next's default missing-key behavior), not an empty string or an exception — confirmed live: `translate('search-for-anything', 'es')` returns the literal string `"search-for-anything"` before `addLocale('es', ...)` is called, then the real Spanish text afterwards. This demo's UI treats any value read back before `addLocale` has been called as "not added yet" without relying on that exact fallback shape.
- **`translate(key, locale)` is the reliable way to prove `addLocale` worked**, independent of whether any of the SDK's own default UI parts happen to be visible on screen at the time — this demo relies on it as its primary signal, not on spotting a UI string change.
- **This complements, but is distinct from, `runtime-locale`.** `runtime-locale` switches the *venue's* displayed locale (POI/label text) between locales already authored for the map at publish time (`en`/`fr` on this app's shared demo map). `add-locale` instead creates a locale that never existed for this map at all, and can only ever affect the SDK's own UI/navigation strings plus custom app keys — never the map's own place names.

## Learn more

- See `docs/features/runtime-locale.md` for switching between locales already authored on the map, and for `setCurrentLocale`'s own async/Promise behavior (unlike `addLocale`/`translate` here, which are synchronous).
- The `Translator` interface also exposes `removeLocale(locale)` and `getLocale(locale): Resources` — not built into this demo's UI, but available on the same object for removing a runtime-added locale or reading back its full resource map.
