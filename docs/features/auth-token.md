# Protected map (authorization token)

## Description

**Code sample only.** Shows how to load a map protected by an authorization token (a JWT) via `LoadOptions.authorizationToken`, refresh that token on a loaded venue via `venue.setAuthorizationToken()`, and recognize the SDK's `UnauthorizedError` apart from other load errors.

This demo has no protected map to ship, so **every value in this repo is a fictitious placeholder** — `YOUR_PROTECTED_MAP_HASH` and `YOUR_JWT_FROM_YOUR_BACKEND` in `VisioOneMeet/ProtectedMapSample.swift`. Replace them with your own values. The app's "Protected map (token)" screen only displays a pointer to this code; it never loads anything.

## SDK usage

Native side — the values to configure, and the entry points (`VisioOneMeet/ProtectedMapSample.swift`):

```swift
enum ProtectedMapSample {
    static let mapHash = "YOUR_PROTECTED_MAP_HASH"
    static let baseURL = "https://mapserver-auth.visioglobe.com/"
    // Issued by YOUR OWN backend; never embed the signing secret in the app.
    static let placeholderToken = "YOUR_JWT_FROM_YOUR_BACKEND"

    static func loadOptions(token: String = placeholderToken) -> ProtectedMapOptions { ... }
}

// Load the protected map instead of the page's default public one:
MapWebView(bridge: bridge, protectedMap: ProtectedMapSample.loadOptions(token: jwtFromYourBackend))

// Before the current token expires:
bridge.setAuthorizationToken(freshJwt)
```

`MapWebView` passes the options to the page as a document-start `WKUserScript` defining `window.VISIOONE_PROTECTED_MAP` (rather than a URL query item, since a JWT doesn't belong in a URL). `setAuthorizationToken(_:)` calls `window.MapBridge.setAuthorizationToken(token)` through `WKWebView.callAsyncJavaScript`.

JS side — the real SDK calls (`VisioOneMeet/WebContent/map.html`):

```js
async function loadProtectedVenue(options) {
  try {
    venue = await visioOne.loadVenue({
      vg_maphash: options.vg_maphash,
      baseURL: options.baseURL,                       // 'https://mapserver-auth.visioglobe.com/'
      authorizationToken: options.authorizationToken,
    }, container);
    onViewCreated(await visioOne.createView(container, venue));
  } catch (error) {
    if (isUnauthorizedError(error)) {
      // Token invalid, expired or missing.
      sendToNative('unauthorized', error.message);
    } else {
      onLoadError(error);
    }
  }
}

if (window.VISIOONE_PROTECTED_MAP) {
  loadProtectedVenue(window.VISIOONE_PROTECTED_MAP);
}

// Token refresh (window.MapBridge):
setAuthorizationToken: function (token) {
  venue.setAuthorizationToken(token);
  return { status: 'applied' };
}
```

Identifying `UnauthorizedError`:

```js
var UNAUTHORIZED_MESSAGE = 'This venue needs an Authorization token to be loaded';
function isUnauthorizedError(error) {
  if (!error) return false;
  return (error.constructor && error.constructor.name === 'UnauthorizedError') ||
    error.message === UNAUTHORIZED_MESSAGE;
}
```

The native side receives the `unauthorized` message separately from the generic `error` one, so the app can tell "get a new token" apart from any other load failure.

## Things to know

- **The token travels as an HTTP header.** The SDK sends `authorizationToken` as `Authorization: Bearer <token>` on every map request. It only makes sense together with the protected map server as `baseURL` (`https://mapserver-auth.visioglobe.com/`): the standard `mapserver.visioglobe.com` does not enforce tokens.
- **A protected map has its own hash**, distinct from any public map hash.
- **`UnauthorizedError` is not exported by the bundled UMD build.** Only `VisioOne`/`createVisioOne` are exported at runtime (the class exists in the TypeScript typings only), so `instanceof UnauthorizedError` is impossible, and `error.name` is the generic `'Error'`. In this bundle the class name survives (`error.constructor.name === 'UnauthorizedError'`, verified); the SDK's message `"This venue needs an Authorization token to be loaded"` is used as a fallback.
- **`UnauthorizedError` is only raised on an HTTP 403** for the map's `descriptor.json` (e.g. no token at all). Any other non-OK response is reported as the generic `Error('Cannot load the venue')`, with the underlying cause only in a `console.warn("VisioOne error:", …)`. Verified in this app's `WKWebView`: with the placeholder hash and token, the server answers an error status for the fake JWT and `loadVenue` rejects with `Error: Cannot load the venue` (console: `The map hash 'YOUR_PROTECTED_MAP_HASH' was not found.`); with an empty token (no `Authorization` header sent), it rejects with `UnauthorizedError: This venue needs an Authorization token to be loaded`. So a malformed token may surface as the generic error, not as `UnauthorizedError`.
- **Tokens are short-lived** (the protected server accepts a lifetime of at most 1 hour). Requests made after expiry are rejected. Call `venue.setAuthorizationToken(freshToken)` before expiry: it updates the token for every subsequent request, no reload needed. Refreshing in time is up to your app.
- **Never embed the JWT signing secret** in the app or the page. Get tokens from your own backend; Visioglobe provides the signing secret and the claims to use.
- **The server checks the request's `Origin` against an allowlist** configured by Visioglobe for your account (CORS; the `Authorization` header forces a preflight). This app loads `map.html` from the app bundle via `loadFileURL`, so the page's `window.location.origin` is `file://` and WebKit sends `Origin: null` on its requests. Tell Visioglobe which origin(s) your app uses; if your page isn't served the same way, its origin will differ. A rejected preflight makes the fetch itself fail, which the SDK also reports as the generic `Error('Cannot load the venue')`.

## Learn more

- [`custom-base-url.md`](./custom-base-url.md) — `LoadOptions.baseURL`, the load-time option this sample points at the protected map server.
