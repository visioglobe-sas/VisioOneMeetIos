# Custom Base URL

## Description

Points the SDK at a different map server than its own built-in default, via `LoadOptions.baseURL` — the argument client apps with data-sovereignty or on-premise hosting requirements would use to move off Visioglobe's SaaS. `baseURL` is the root every map asset (config, tiles, icons) is fetched from; the SDK's own default, when the option is omitted entirely, is `https://mapserver.visioglobe.com/`.

Unlike every other bridge-driven demo screen in this app, `baseURL` cannot be changed on an already-loaded venue/view — it only takes effect at `loadVenue` time. So this screen's "Reload" action re-loads the whole page rather than calling into an existing `venue`/`view` instance.

## SDK usage

```js
// VisioOneMeet/WebContent/bridge/core.js, MapCore.start() — hash is always
// read the same way; baseURL is a second, independent override read the
// same way, empty/omitted meaning "let the SDK's own default apply".
var params = new URLSearchParams(window.location.search);
var hash = params.get('vg_maphash');
var baseURL = params.get('baseURL');

loadMap(
  baseURL ? { vg_maphash: hash, baseURL: baseURL } : { vg_maphash: hash },
  Object.keys(viewOptions).length ? viewOptions : undefined
).catch(onLoadError);

// Same file: loadMap = visioOne.loadVenue(loadOptions, container), then
// visioOne.createView(container, venue, viewOptions?).
function onLoadError(error) {
  visioOne.showError(error, container);
  sendToNative('error', errorMessage(error));
}
```

```swift
// VisioOneMeet/Shell/MapWebView.swift — same override mechanism this app
// already uses for a custom map hash (see docs/features/custom-data.md),
// extended with a second, independent query item.
var baseURLOverride: String?

// ...
if let baseURLOverride {
    queryItems.append(URLQueryItem(name: "baseURL", value: baseURLOverride))
}
```

```swift
// VisioOneMeet/Features/CustomBaseUrl/CustomBaseUrl+Bridge.swift — baseURL
// can't be mutated on a live venue/view, so "Reload" has to redo the whole
// page load rather than call into the existing one.
func reloadWithBaseURL(_ newBaseURL: String) {
    var options = pageOptions
    options.baseURL = newBaseURL
    reloadPage(with: options)
}

// VisioOneMeet/Bridge/VisioOneBridge.swift — the view hosting MapWebView
// keys it with .id(bridge.pageOptions), so a new baseURL tears down and
// recreates the WKWebView (a fresh loadFileURL with the new ?baseURL= query
// item); retrying the exact same value just loads the page again.
func reloadPage(with options: MapPageOptions) {
    if options == pageOptions {
        reload()
    } else {
        willReload()          // loadState = .loading, features reset their map state
        pageOptions = options
    }
}
```

`loadVenue(options: LoadOptions, container: HTMLElement): Promise<Venue>` throws a typed, catchable `VenueNotFoundError` (a plain `Error` subclass) when the hash or `baseURL` is invalid — this app already surfaces that through the exact same `.catch(onLoadError)` → `sendToNative('error', ...)` → `.error(message)` overlay every other feature falls back to on a bad hash, no new error-handling path needed for this feature.

## Things to know

- **`baseURL` is a load-time option, not a live property.** Every other feature in this app mutates an already-loaded `venue`/`view` (colors, locale, tracked position, …); this one is the exception — changing it requires a full venue reload, which is why "Reload" here recreates the whole `WKWebView` rather than calling a bridge method on the existing one.
- **A bad `baseURL` is a clean, catchable failure, not a hang.** Passing an unreachable `baseURL` rejects `loadVenue`'s promise almost immediately with `Error: Cannot load the venue` — the same error path a bad hash already takes, not a stall or an uncaught exception.
- **Passing the SDK's own real default value through explicitly behaves identically to omitting it.** `?baseURL=https://mapserver.visioglobe.com/` loads exactly like no override at all — proving the parameter is genuinely wired through to `loadVenue`, not just a UI field with no effect.
- There is no second real map-hosting environment to demonstrate an actual working alternate deployment against — hosting one is a separate infrastructure decision, out of scope for this demo app (see the hub's `docs/features/custom-base-url.md`). The error-state case above is the honest substitute: it proves the plumbing works without fabricating infrastructure that doesn't exist.

## Learn more

- [`custom-data.md`](./custom-data.md) — the other feature overriding this app's default map hash via the same query-param mechanism `baseURL` reuses here.
