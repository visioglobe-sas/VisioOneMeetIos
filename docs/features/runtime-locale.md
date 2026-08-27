# Runtime Locale

## Description

Switches the map's displayed language — POI/label names — at runtime, without reloading or republishing the map, via the venue-level locale API: `venue.currentLocale` (readonly) and `venue.setCurrentLocale(locale)`. Calling `setCurrentLocale` is enough on its own: per the SDK's own doc comment, the SDK re-renders every POI/label's text (and any current View UI, including the active Navigation) for the new locale by itself — there is no need to manually re-fetch or re-render POI data after the switch.

## SDK usage

```js
// window.MapBridge, JS side
getCurrentLocale: function () {
  if (!venue) return null;
  return venue.currentLocale;
},
setCurrentLocale: function (locale) {
  if (!venue) return Promise.reject(new Error('venue not loaded'));
  return venue.setCurrentLocale(locale);
},
```

```swift
/// Reads venue.currentLocale (synchronous JS property, no promise involved).
func refreshCurrentLocale() async {
    guard let webView else { return }
    let result: String? = await withCheckedContinuation { continuation in
        webView.evaluateJavaScript("window.MapBridge.getCurrentLocale()") { result, error in
            // ... continuation.resume(returning: result as? String)
        }
    }
    if let result { currentLocale = result }
}

/// Calls venue.setCurrentLocale(locale) and awaits its Promise via
/// callAsyncJavaScript, only updating `currentLocale` once it resolves.
@discardableResult
func setCurrentLocale(_ locale: String) async -> Bool {
    guard let webView else { return false }
    return await withCheckedContinuation { continuation in
        webView.callAsyncJavaScript(
            "return await window.MapBridge.setCurrentLocale(locale);",
            arguments: ["locale": locale],
            in: nil,
            in: .page
        ) { result in
            // ... on success: currentLocale = locale; continuation.resume(returning: true)
            // ... on failure: continuation.resume(returning: false)
        }
    }
}
```

`venue.currentLocale: string` is a readonly, synchronous property — read straight from `evaluateJavaScript`'s own return value, the same idiom used for `venue.categories` in `docs/features/category-highlight.md`. `venue.setCurrentLocale(locale: string): Promise<void>` is the actual call that performs the switch; because it returns a real `Promise` the SDK awaits internally, the native side calls it via `WKWebView.callAsyncJavaScript` (the same idiom `docs/features/custom-data.md` and `docs/features/dynamic-poi-crud.md` use for their own promise-returning calls) rather than a plain `evaluateJavaScript` string, and only reflects the new locale as "current" once that promise actually settles.

The full set of locales a venue supports is exposed as `venue.translator.allLocales: string[]`, not used directly by this demo's UI (see below).

## Things to know

- **`setCurrentLocale` is asynchronous — it returns a `Promise<void>`, not a synchronous mutation.** `venue.currentLocale` does not reflect the new value until that promise resolves. Treating the call as fire-and-forget (as this repo's `highlightCategory`/`setSurfaceInteractive` do for their own SDK calls) would let the UI show the wrong "active" locale for a brief window, or forever if the promise ever rejects — so this feature genuinely awaits it before updating any locale-dependent UI state, unlike most of this repo's other bridge calls.
- **`venue.translator.allLocales` on this app's shared demo map is `['en', 'fr']` only — `'default'` is *not* listed by that property**, confirmed live with a standalone `WKWebView` harness loading this exact `map.html` + the vendored SDK bundle (`JSON.stringify(venue.translator.allLocales)` → `["en","fr"]`). `'default'` is nonetheless a working value: calling `venue.setCurrentLocale('default')` succeeds and, on this map, renders byte-identical POI/label text to `'fr'` (both are French) — verified by comparing 30 POI labels between the two. Presenting `'default'` as a third, seemingly-distinct language option in this demo's UI would therefore be both redundant (with `'fr'`) *and* invisible in `allLocales` itself. This demo hardcodes the two meaningfully-different options, `en` and `fr`, rather than driving the picker off `allLocales`. An integrator should not assume `allLocales`'s contents fully describe every locale string the venue will actually accept.
- **`setCurrentLocale` does not validate its argument.** Calling it with an unrecognized locale string (e.g. `'zz-bogus'`) still resolves successfully — no rejection — and `venue.currentLocale` afterwards reports back whatever string was passed, even though it matches no real `LocaleEntry`. Labels don't go blank in that case; they fall back to the same base text shown under `'default'`/`'fr'`. Don't rely on the promise rejecting to catch a typo'd or unsupported locale code.
- **No SDK event fires when the locale changes.** Unlike `currentfloorchanged` (used by `docs/features/floor-selector.md`), there is no `localechanged`-style event to subscribe to — the only way to know the switch happened is to await the `setCurrentLocale` promise itself.

## Learn more

- See `docs/features/floor-selector.md` for another feature reading a translated display value via `venue.translator` (there, `translateBuilding`/`translateFloor`, driven off the same `currentLocale` this feature switches).
- See `docs/features/category-highlight.md` for `venue.translator.translateCategory()`, whose output also changes once `setCurrentLocale` resolves, even though this demo doesn't wire the two features together.
