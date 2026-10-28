// camera-showcase-carousel: an automatic camera tour (kiosk / lobby screen):
// goToFloor + goToPOI on each stop in order, forever, with a dwell in
// between. The loop lives here, at page level (one page = one feature
// screen), never in the native panel: closing the panel must not stop it,
// and there is only ever one loop. Native only sends start/stop and mirrors
// the state pushed back by sendCarouselState() ('carouselStateChanged').
// The stop ids come from native with each start (DemoMap.carouselStopIds).
// See docs/features/camera-showcase-carousel.md.
(function (core) {
  var CAROUSEL_STOP_IDS = [];
  var CAROUSEL_DWELL_MS = 3000;
  var CAROUSEL_RESUME_DELAY_MS = 10000;
  var carouselState = 'stopped'; // 'running' | 'paused' | 'stopped'
  var carouselIndex = 0;
  // Bumped on every start/pause/stop: a loop iteration whose run token is
  // no longer current exits at its next await, so there's never more than
  // one live loop even if an old await settles late.
  var carouselRun = 0;
  var carouselDwellTimer = null;
  var carouselResumeTimer = null;
  // The SDK AnimationPromise currently driving the camera for the tour
  // (null between hops), so a pause/stop knows whether there's a camera
  // animation to interrupt.
  var carouselAnimation = null;

  function sendCarouselState() {
    core.sendToNative('carouselStateChanged', {
      state: carouselState,
      stop: carouselIndex + 1,
      total: CAROUSEL_STOP_IDS.length,
      poiId: CAROUSEL_STOP_IDS[carouselIndex],
    });
  }

  function clearCarouselTimers() {
    if (carouselDwellTimer) clearTimeout(carouselDwellTimer);
    if (carouselResumeTimer) clearTimeout(carouselResumeTimer);
    carouselDwellTimer = null;
    carouselResumeTimer = null;
  }

  // Interrupts the tour's in-flight camera animation WITHOUT moving the
  // camera. Starting another camera animation interrupts the running one in
  // place (its promise resolves with isCanceled === true, the camera stays
  // where it is), so this starts a zero-length goToViewpoint on the camera's
  // current target, keeping the current heading/pitch.
  // (animation.cancel() also stops the camera where it is, despite its
  // typing saying it puts the target in its final state; see
  // docs/features/camera-showcase-carousel.md.)
  function interruptCarouselAnimation() {
    var view = core.view;
    if (!view || !carouselAnimation) return;
    carouselAnimation = null;
    var camera = view.camera;
    view.goToViewpoint(
      { positions: [camera.target] },
      { duration: 0, orientation: { heading: camera.heading, pitch: camera.pitch } }
    );
  }

  // Wraps one SDK camera animation of the tour. Resolves to true when the
  // loop may go on, false when it must exit: the run was paused/stopped
  // (token changed) or the SDK reports the animation was interrupted by
  // another camera animation (isCanceled).
  function carouselStep(run, animation) {
    carouselAnimation = animation;
    return animation.then(function () {
      if (carouselAnimation === animation) carouselAnimation = null;
      return run === carouselRun && !animation.isCanceled;
    });
  }

  async function runCarousel(run) {
    var view = core.view;
    while (run === carouselRun) {
      var poiId = CAROUSEL_STOP_IDS[carouselIndex];
      var poi = core.findPoi(poiId);
      if (poi) {
        sendCarouselState();
        // Documented order: switch floor first, then goToPOI.
        if (poi.floor && !(await carouselStep(run, view.goToFloor(poi.floor, { duration: 800 })))) break;
        var ok = await carouselStep(run, view.goToPOI(poi, {
          duration: 2500,
          easing: 'easeInOutQuad',
          orientation: { heading: carouselIndex * 90, pitch: 30 },
        }));
        if (!ok) break;
        await new Promise(function (resolve) { carouselDwellTimer = setTimeout(resolve, CAROUSEL_DWELL_MS); });
        carouselDwellTimer = null;
        if (run !== carouselRun) break;
      } else {
        console.warn('[VisioOne:web] carousel stop not found:', poiId);
      }
      carouselIndex = (carouselIndex + 1) % CAROUSEL_STOP_IDS.length;
    }
    // Interrupted by a camera animation the tour didn't start (e.g. the
    // SDK's own UI): stop rather than fight it.
    if (run === carouselRun && carouselState === 'running') {
      carouselRun++;
      carouselState = 'stopped';
      sendCarouselState();
    }
  }

  function startCarouselFrom(index) {
    if (!core.venue || !core.view) return;
    clearCarouselTimers();
    carouselRun++;
    carouselIndex = index % CAROUSEL_STOP_IDS.length;
    carouselState = 'running';
    runCarousel(carouselRun);
  }

  // A touch on the map pauses the tour immediately so the user's gesture
  // wins (the SDK doesn't interrupt its own camera animations on user input,
  // and fires no "camera moved by user" event), then resumes from the next
  // stop after CAROUSEL_RESUME_DELAY_MS without any touch. Capture phase on
  // the container, so it runs before the SDK's own handlers on the canvas.
  function onCarouselTouch() {
    if (carouselState === 'stopped') return;
    if (carouselState === 'running') {
      carouselRun++;
      clearCarouselTimers();
      interruptCarouselAnimation();
      carouselState = 'paused';
      sendCarouselState();
    }
    if (carouselResumeTimer) clearTimeout(carouselResumeTimer);
    carouselResumeTimer = setTimeout(function () {
      carouselResumeTimer = null;
      if (carouselState === 'paused') startCarouselFrom(carouselIndex + 1);
    }, CAROUSEL_RESUME_DELAY_MS);
  }
  core.container.addEventListener('pointerdown', onCarouselTouch, true);
  // A long drag still counts as touching: re-arm the idle delay on release.
  core.container.addEventListener('pointerup', function () {
    if (carouselState === 'paused') onCarouselTouch();
  }, true);

  core.onReset(function () {
    carouselRun++;
    clearCarouselTimers();
    carouselAnimation = null;
    carouselState = 'stopped';
    carouselIndex = 0;
  });

  core.register({
    // Starts the camera tour over stopIds (POI ids, in order) from the first
    // stop (no-op if already running or paused).
    startCarousel: function (stopIds) {
      if (carouselState !== 'stopped') return;
      if (!Array.isArray(stopIds) || stopIds.length === 0) return;
      CAROUSEL_STOP_IDS = stopIds;
      startCarouselFrom(0);
    },
    // Stops the tour for good: no more hop is scheduled, a pending
    // auto-resume is dropped, and an in-flight hop is interrupted where the
    // camera currently is (it doesn't fly on to its destination). Also called
    // by native when leaving the screen.
    stopCarousel: function () {
      if (carouselState === 'stopped') return;
      carouselRun++;
      clearCarouselTimers();
      interruptCarouselAnimation();
      carouselState = 'stopped';
      sendCarouselState();
    },
  });
})(window.MapCore);
