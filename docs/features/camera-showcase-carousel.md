# Camera showcase

## Description

An automatic camera tour of the map, for kiosks and lobby screens: the camera flies to a fixed list of POIs one after the other, forever, across several buildings and floors. Each hop is `view.goToFloor()` (switch to the POI's floor) followed by `view.goToPOI()` with a custom `duration`, `easing` and `orientation` (heading + pitch), then a short dwell before the next stop.

Touching the map pauses the tour immediately, so the user's gesture wins over the camera animation, and the tour resumes on its own from the next stop after 10 s without any touch. A Stop command ends it for good.

All of it is built on the SDK's camera animation API: `view.goToFloor()`, `view.goToPOI()`, `view.goToViewpoint()`, each returning an `AnimationPromise`, plus `view.camera` (read-only target, heading and pitch).

## SDK usage

The loop lives in the web page (`map.html`), next to the SDK, not in native code: it needs to `await` each `AnimationPromise` and read `isCanceled`, and keeping it there means there is exactly one loop per map, whatever the native UI does. Native only sends start/stop and displays the state the page pushes back.

```js
// map.html
var STOPS = [];          // POI ids, in order: sent by native with startCarousel()
var state = 'stopped';   // 'running' | 'paused' | 'stopped'
var index = 0;
var run = 0;             // bumped on every start/pause/stop: an old loop exits at its next await
var currentAnimation = null;

// One SDK camera animation of the tour. Resolves to false when the loop
// must exit: the run was paused/stopped, or the SDK reports the animation
// was interrupted by another camera animation (isCanceled).
function step(myRun, animation) {
  currentAnimation = animation;
  return animation.then(function () {
    if (currentAnimation === animation) currentAnimation = null;
    return myRun === run && !animation.isCanceled;
  });
}

async function loop(myRun) {
  while (myRun === run) {
    var poi = venue.pois.find(function (p) { return p.id === STOPS[index]; });
    sendToNative('carouselStateChanged', { state: state, stop: index + 1, total: STOPS.length, poiId: poi.id });

    // Documented order: switch floor first, then goToPOI.
    if (!(await step(myRun, view.goToFloor(poi.floor, { duration: 800 })))) break;
    if (!(await step(myRun, view.goToPOI(poi, {
      duration: 2500,
      easing: 'easeInOutQuad',                       // animejs/Penner easing name
      orientation: { heading: index * 90, pitch: 30 }, // degrees
    })))) break;

    await new Promise(function (resolve) { setTimeout(resolve, 3000); }); // dwell
    if (myRun !== run) break;
    index = (index + 1) % STOPS.length;
  }
}

// Stops the in-flight camera animation WHERE THE CAMERA IS, by starting
// another animation: it interrupts the running one in place.
// (animation.cancel() would stop the camera in place too.)
function interruptInPlace() {
  if (!currentAnimation) return;
  currentAnimation = null;
  var camera = view.camera;
  view.goToViewpoint(
    { positions: [camera.target] },
    { duration: 0, orientation: { heading: camera.heading, pitch: camera.pitch } }
  );
}

// The SDK neither interrupts its own animations on user input nor reports
// user camera moves, so detect touches yourself: capture phase on the map
// container, so this runs before the SDK's own handlers on the canvas.
container.addEventListener('pointerdown', function () {
  if (state === 'stopped') return;
  if (state === 'running') {
    run++;
    interruptInPlace();
    state = 'paused';
    sendToNative('carouselStateChanged', { state: 'paused' });
  }
  clearTimeout(resumeTimer);
  resumeTimer = setTimeout(function () { startFrom(index + 1); }, 10000);
}, true);
// (the real page also re-arms the 10 s delay on pointerup, so a long drag counts as touching)

window.MapBridge = {
  startCarousel: function (stopIds) {
    if (state !== 'stopped' || !stopIds.length) return;
    STOPS = stopIds;
    startFrom(0);
  },
  stopCarousel: function () {
    if (state === 'stopped') return;
    run++;
    clearTimeout(resumeTimer);
    interruptInPlace();
    state = 'stopped';
    sendToNative('carouselStateChanged', { state: 'stopped' });
  },
};
```

```swift
// VisioOneBridge.swift: native -> JS
// The stops (DemoMap.carouselStopIds: replace them with your own map's POI
// ids), JSON-encoded so they arrive as a real JS array.
func startCarousel(stopIds: [String] = DemoMap.carouselStopIds) {
    guard let data = try? JSONSerialization.data(withJSONObject: stopIds),
          let json = String(data: data, encoding: .utf8) else { return }
    webView?.evaluateJavaScript("window.MapBridge.startCarousel(\(json))")
}
func stopCarousel() {
    webView?.evaluateJavaScript("window.MapBridge.stopCarousel()")
}

// JS -> native (WKScriptMessageHandler): the page pushes every state change,
// including the ones native didn't ask for (a touch pausing the tour, the
// idle timer resuming it), so the UI always shows the real state.
case "carouselStateChanged":
    switch payload["state"] as? String {
    case "running": carouselStatus = .running(stop: ..., total: ..., poiId: ...)
    case "paused":  carouselStatus = .paused
    default:        carouselStatus = .stopped
    }
```

Leaving the screen calls `stopCarousel()`. The `WKWebView` is torn down anyway, but stopping explicitly doesn't depend on that.

## Things to know

- **`goToFloor`, `goToPOI` and `goToViewpoint` return an `AnimationPromise`**: a `Promise<void>` with an `isCanceled` flag and a `cancel()` method. It always resolves (it doesn't reject when interrupted), so after each `await` check `isCanceled` and whether your loop was stopped.
- **`animation.cancel()` stops the camera where it is.** It resolves the promise right away with `isCanceled === true` and leaves the camera in the state it is in at the moment of the call. The public typing of `cancel()` says it "puts the animation target in its final state": that wording is wrong. The SDK core implementation (1.1.0) documents and implements the opposite, and live measurements (Android `WebView`, iOS `WKWebView`) confirm it. This page interrupts with a zero-length `goToViewpoint` instead (see below); both stop the camera in place.
- **A new camera animation interrupts the running one in place.** Its promise resolves with `isCanceled === true` and the camera continues from where it was, with no jump to the old destination. That's how this page stops a hop where it is: a zero-length `goToViewpoint` on `view.camera.target`, passing the current `view.camera.heading`/`pitch` as `orientation`. Measured on iOS: a pause mid-`goToPOI` moved the camera target by about 1.5 m. The altitude went from 35.4 to 34.0 m, while the hop's destination was about 30 m away. A Stop mid-hop moved it by about 1 m (destination about 65 m away).
- **Known SDK issue (1.1.0): the camera can break after a drag on an underground floor.** Observed on another platform: after `goToPOI` with `orientation: { heading: 90 or 180, pitch: 45 }` on the underground POI `B1-LL01-ID0152` (floor `B1-LL1`, camera at its 10 m minimum altitude), one or two user drags turned `view.camera.heading` into `NaN` and `pitch` into `0`, and the map rendered black until the view was reloaded. It is not systematically reproducible; pitch 30 did not trigger it in the attempts made, so the demo uses `pitch: 30`.
- **User gestures don't interrupt SDK animations, and there's no "camera moved by user" event.** A drag during a `goToPOI` doesn't stop it, so the user ends up fighting the camera until the animation ends. Detect touches yourself (`pointerdown` on the map container, capture phase) and stop scheduling. Once the animation is interrupted, the drag moves the camera normally.
- **Call `goToFloor(poi.floor)` before `goToPOI(poi)`.** The SDK docs make the caller responsible for the floor switch when the POI is on another floor. Without it, `currentFloor`/`currentBuilding` stay where they were. In SDK 1.1.0, `goToPOI` alone did switch the floor in a test on the web sibling app, but follow the documented order.
- **`orientation` takes degrees**: `heading` relative to north and `pitch` from the vertical. Either can also be `'initial'`. Without `orientation`, `goToPOI` keeps its own default framing. `view.camera.heading` reads back normalized: a hop with `heading: 270` ends at `-90`.
- **`easing` is an animejs/Penner easing name** (e.g. `'easeInOutQuad'`). `duration` is in milliseconds. Measured hops were close to the requested durations: `goToFloor` about 0.82 s for `duration: 800` (one first-time switch to another building took 1.9 s), and `goToPOI` about 2.52 s for `duration: 2500`.
- `goToFloor` changes the zoom level as well as the floor: it frames the whole floor (camera altitude about 230-270 m on the demo map) before `goToPOI` zooms in (10-63 m depending on the POI).

## Learn more

- [Go to a POI](goto-poi.md): a single `goToFloor` + `goToPOI` hop with a surface highlight.
- [Floor/building selector](floor-selector.md): `goToFloor`/`goToBuilding` and the `currentfloorchanged` event.
