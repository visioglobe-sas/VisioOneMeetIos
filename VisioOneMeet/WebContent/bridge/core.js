// Core of the page's JS bridge: loads the map (venue + view), owns the
// single JS -> native channel, the helpers shared by several features, and
// the registration API the feature files use.
//
// Every feature lives in its own file, `features/<slug>.js` (same slug as
// `docs/features/<slug>.md`), loaded AFTER this one by a classic
// `<script src>` tag in `map.html` -- no ES modules: their imports fail
// under file:// in WKWebView. A feature file:
//   - adds its native -> JS commands to `window.MapBridge` through
//     `MapCore.register({ ... })`;
//   - adds its view event listeners through `MapCore.onViewCreated(fn)`,
//     and pushes its initial state to native through `MapCore.onReady(fn)`;
//   - forgets the SDK objects it created through `MapCore.onReset(fn)`.
// `bridge/bootstrap.js`, loaded last, then calls `MapCore.start()`.
// See docs/APP_SDK_COMMUNICATION.md.
(function () {
  var visioOne = VisioOne.createVisioOne();
  var container = document.getElementById('container');
  var venue = null;
  var view = null;

  var resetHooks = [];
  var viewCreatedHooks = [];
  var readyHooks = [];

  // JS -> native: the single message channel back to Swift
  // (window.webkit.messageHandlers.mapBridge, received by
  // VisioOneBridge.userContentController). Carries the loading lifecycle
  // ('ready'/'error') and every SDK event the native UI mirrors. See
  // docs/APP_SDK_COMMUNICATION.md for the pattern.
  function sendToNative(type, message) {
    var handler = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.mapBridge;
    if (!handler) {
      console.log('[VisioOne:web]', type, message);
      return;
    }
    handler.postMessage({ type: type, message: message });
  }

  // Error -> message string, for the `{ status: 'error', message }` results.
  function errorMessage(e) {
    return e && e.message ? e.message : String(e);
  }

  function findPoi(poiId) {
    return venue ? venue.pois.find(function (p) { return p.id === poiId; }) : undefined;
  }

  // A POI has no lat/lng field of its own: its display position is read
  // off the objects attached to it, in this order:
  //   1. its first label's `position`,
  //   2. else its first image's `position`, else its first marker's,
  //   3. else the centroid of its first surface's `positions`.
  // Returns null when the POI has none of these. Every feature that needs
  // "where is this POI" (simulated-position and the other tracking
  // screens, dynamic-poi-crud, 3d-icon-marker, custom-text-label,
  // html-overlay-marker) uses this one helper, so a given POI always
  // resolves to the same point.
  // `exclude` (optional) is one of OUR OWN objects attached to that POI
  // (the text label, icon image or HTML badge marker this page placed on
  // it), skipped so a re-place never reads its position back from itself
  // (the ~4 m offset would otherwise build up).
  function poiDisplayPosition(poi, exclude) {
    function firstWithPosition(list) {
      return (list || []).find(function (o) { return o !== exclude && o.position; });
    }
    var item = firstWithPosition(poi.labels) || firstWithPosition(poi.images) || firstWithPosition(poi.markers);
    if (item) {
      return { latitude: item.position.latitude, longitude: item.position.longitude, altitude: item.position.altitude };
    }
    var surface = (poi.surfaces || []).find(function (sf) { return sf.positions && sf.positions.length > 0; });
    if (!surface) return null;
    var sum = surface.positions.reduce(function (acc, p) {
      return {
        latitude: acc.latitude + p.latitude,
        longitude: acc.longitude + p.longitude,
        altitude: acc.altitude + (p.altitude || 0),
      };
    }, { latitude: 0, longitude: 0, altitude: 0 });
    var count = surface.positions.length;
    return { latitude: sum.latitude / count, longitude: sum.longitude / count, altitude: sum.altitude / count };
  }

  // `position` moved ~4 m north-east, so a label/badge placed next to a
  // POI doesn't overlap the POI's own map label.
  function offsetPosition(position) {
    return {
      latitude: position.latitude + 0.00004,
      longitude: position.longitude + 0.00004,
      altitude: position.altitude,
    };
  }

  // Shared by compute-navigation, navigation-exclude-modalities and
  // accessible-mode: venue.computeNavigation() ->
  // venue.createNavigationTrace() -> view.setCurrentNavigationTrace(),
  // which replaces whatever route was current. The trace is kept in
  // `core.currentNavigationTrace` (NavigationTrace isn't JSON-serializable)
  // so custom-navigation-trace can restyle it. Errors thrown by
  // computeNavigation (e.g. unknown POI id, no route) propagate to the
  // caller. See docs/features/compute-navigation.md.
  function showNavigation(request, excludedAttributes) {
    if (!venue || !view) return;
    var options = {
      origin: request.origin,
      destination: request.destination,
      isAccessible: request.isAccessible,
      type: 'fastest',
      firstNodeAsIntersection: false,
      mergeFloorChangeInstructions: false,
    };
    if (excludedAttributes) options.excludedAttributes = excludedAttributes;
    var navigationTrace = venue.createNavigationTrace(venue.computeNavigation(options));
    core.currentNavigationTrace = navigationTrace;
    view.setCurrentNavigationTrace(navigationTrace);
  }

  function runHooks(hooks, arg) {
    hooks.forEach(function (hook) { hook(arg); });
  }

  // Everything the demo screens need once the view exists: each feature's
  // view listeners, then 'ready' (with the projection the view actually
  // reports, read-only, so camera-projection-toggle shows the real state
  // rather than the one it requested), then each feature's initial state.
  function onViewCreated(v) {
    view = v;
    runHooks(viewCreatedHooks, view);
    sendToNative('ready', { cameraProjection: view.cameraProjection });
    runHooks(readyHooks, view);
  }

  function onLoadError(error) {
    visioOne.showError(error, container);
    sendToNative('error', errorMessage(error));
  }

  // loadVenue + createView. `viewOptions` may be undefined (SDK defaults).
  // Rejects on any failure, so each caller picks its own error handling.
  function loadMap(loadOptions, viewOptions) {
    return visioOne.loadVenue(loadOptions, container)
      .then(function (v) {
        venue = v;
        return viewOptions
          ? visioOne.createView(container, venue, viewOptions)
          : visioOne.createView(container, venue);
      })
      .then(onViewCreated);
  }

  // Native -> JS bridge: one method per command, each added by its feature
  // file through `register`. Called from Swift through
  // WKWebView.callAsyncJavaScript() (`VisioOneBridge.call`/`callForResult`),
  // which passes the arguments as real JS values -- never a string to
  // re-parse -- and waits for a returned Promise to settle. See
  // docs/APP_SDK_COMMUNICATION.md.
  window.MapBridge = {};

  // API used by the `features/<slug>.js` files.
  var core = {
    container: container,
    visioOne: visioOne,

    // The NavigationTrace currently displayed (see showNavigation), null
    // until a route is computed.
    currentNavigationTrace: null,

    sendToNative: sendToNative,
    errorMessage: errorMessage,
    findPoi: findPoi,
    poiDisplayPosition: poiDisplayPosition,
    offsetPosition: offsetPosition,
    showNavigation: showNavigation,
    loadMap: loadMap,
    onLoadError: onLoadError,

    // Adds commands to `window.MapBridge`. A name already taken is a wiring
    // error (two features stepping on each other): logged and ignored.
    register: function (methods) {
      Object.keys(methods).forEach(function (name) {
        if (window.MapBridge[name]) {
          console.error('[MapBridge] command already registered: ' + name);
          return;
        }
        window.MapBridge[name] = methods[name];
      });
    },

    // `fn()` runs at the start of every map load (`start`): the feature
    // forgets the SDK objects it created. The WKWebView reloads the whole
    // page for every new load (Retry, custom-base-url,
    // camera-projection-toggle), so this runs once per page today; it keeps
    // each feature's state reset in one obvious place.
    onReset: function (fn) {
      resetHooks.push(fn);
    },

    // `fn(view)` runs once the view exists, before 'ready': the feature adds
    // its view event listeners there.
    onViewCreated: function (fn) {
      viewCreatedHooks.push(fn);
    },

    // `fn(view)` runs right after 'ready': the feature pushes its initial
    // state to native there.
    onReady: function (fn) {
      readyHooks.push(fn);
    },

    // Loads the map. Called once by bootstrap.js, after every feature file.
    start: function () {
      core.currentNavigationTrace = null;
      runHooks(resetHooks);

      // auth-token code sample: a token-protected map, injected by native
      // as window.VISIOONE_PROTECTED_MAP (see features/auth-token.js).
      if (window.VISIOONE_PROTECTED_MAP && core.loadProtectedVenue) {
        core.loadProtectedVenue(window.VISIOONE_PROTECTED_MAP);
        return;
      }

      var params = new URLSearchParams(window.location.search);

      // Map hash to load, always passed by native as a `?vg_maphash=` query
      // param (MapWebView.swift; the values live in DemoMap.swift): the
      // shared demo map for every screen, a dedicated one for custom-data
      // (see docs/features/custom-data.md).
      // Since SDK 1.0.6 the SDK itself also reads `?vg_maphash=` from the
      // page URL as an override of LoadOptions.vg_maphash, so both paths
      // agree on the same value.
      var hash = params.get('vg_maphash');

      // Same override mechanism as `hash` above, for the custom-base-url
      // feature: lets that one screen point loadVenue at a caller-supplied
      // baseURL (the root the SDK fetches all map data -- config/tiles/icons
      // -- from, defaulting to the SDK's own https://mapserver.visioglobe.com/)
      // instead of always relying on the SDK's built-in default. See
      // docs/features/custom-base-url.md.
      var baseURL = params.get('baseURL');

      // Per-screen createView option for the custom-theme feature only:
      // view.setTheme() only changes the scene lights, which are rendered
      // only when the view is created with enableShadows: true
      // (computationally expensive, so every other screen keeps the SDK
      // default). MapWebView.swift appends `?enableShadows=1` for that one
      // screen. See docs/features/custom-theme.md.
      var enableShadows = params.get('enableShadows') === '1';

      // Per-screen createView option for the camera-projection-toggle
      // feature only: cameraProjection is a creation-time option
      // (view.cameraProjection is read-only, there is no runtime setter), so
      // switching it means a whole new page load -- a fresh loadVenue +
      // createView. MapWebView.swift appends
      // `?cameraProjection=orthographic|perspective` for that one screen;
      // absent everywhere else, so every other screen keeps the SDK default
      // ('perspective'). Deliberately NOT the SDK's own `?orthographic` URL
      // flag (presence-only, can't express "perspective" explicitly). See
      // docs/features/camera-projection-toggle.md.
      var cameraProjection = params.get('cameraProjection');

      var viewOptions = {};
      if (enableShadows) viewOptions.enableShadows = true;
      if (cameraProjection === 'orthographic' || cameraProjection === 'perspective') {
        viewOptions.cameraProjection = cameraProjection;
      }

      loadMap(
        baseURL ? { vg_maphash: hash, baseURL: baseURL } : { vg_maphash: hash },
        Object.keys(viewOptions).length ? viewOptions : undefined
      ).catch(onLoadError);
    },
  };

  // Current venue/view, null until the map is loaded.
  Object.defineProperty(core, 'venue', { get: function () { return venue; } });
  Object.defineProperty(core, 'view', { get: function () { return view; } });

  window.MapCore = core;
})();
