// auth-token code sample: loads a map protected by an authorization token
// (JWT), and refreshes that token. The options are defined on the native
// side (ProtectedMapSample.swift, placeholders to replace) and injected as
// window.VISIOONE_PROTECTED_MAP before this page runs (MapWebView.swift);
// core.start() then calls loadProtectedVenue() instead of loading the public
// demo map. The SDK sends the token as an `Authorization: Bearer <token>`
// header on every map request. No demo screen uses it. See
// docs/features/auth-token.md.
(function (core) {
  // The UMD build does not export the SDK's error classes (no instanceof
  // possible) and error.name is the generic 'Error': the class name, kept in
  // this bundle, identifies an UnauthorizedError, with the SDK's own message
  // as a fallback.
  var UNAUTHORIZED_MESSAGE = 'This venue needs an Authorization token to be loaded';
  function isUnauthorizedError(error) {
    if (!error) return false;
    return (error.constructor && error.constructor.name === 'UnauthorizedError') ||
      error.message === UNAUTHORIZED_MESSAGE;
  }

  core.loadProtectedVenue = function (options) {
    return core.loadMap({
      vg_maphash: options.vg_maphash,
      baseURL: options.baseURL,
      authorizationToken: options.authorizationToken,
    }, undefined).catch(function (error) {
      if (isUnauthorizedError(error)) {
        // Token invalid, expired or missing: get a new one from your backend
        // and load again.
        core.visioOne.showError(error, core.container);
        core.sendToNative('unauthorized', error.message);
      } else {
        core.onLoadError(error);
      }
    });
  };

  core.register({
    // Token refresh. Updates the token used by every later map request of
    // the loaded venue (no reload). Call it before the current token
    // expires.
    setAuthorizationToken: function (token) {
      var venue = core.venue;
      if (!venue) return { status: 'error', message: 'No venue loaded' };
      try {
        venue.setAuthorizationToken(token);
      } catch (e) {
        return { status: 'error', message: core.errorMessage(e) };
      }
      return { status: 'applied' };
    },
  });
})(window.MapCore);
