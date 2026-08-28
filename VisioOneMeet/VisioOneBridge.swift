import Foundation
import WebKit

/// Mirrors the SDK's loading lifecycle (see `docs/features/loading-state.md`).
enum MapLoadState: Equatable {
    case loading
    case ready
    case error(String)
}

/// A POI tapped on the map, forwarded by the SDK's `poiclick` event
/// (see `docs/features/poi-click.md`). `name` mirrors whatever the SDK
/// resolves as the POI's first label for the current locale — `nil` if the
/// POI has no label at all.
struct TappedPOI: Equatable {
    let id: String
    let name: String?
}

/// One floor of a `VenueBuilding`, as pushed by the SDK's `floorsChanged`
/// bridge message (see `docs/features/floor-selector.md`). `label` is
/// already localized on the JS side (SDK translator), never a raw ID.
struct VenueFloor: Equatable, Identifiable {
    let id: String
    let label: String
}

/// One building of the loaded venue, with its floors sorted top-to-bottom
/// (see `docs/features/floor-selector.md`).
struct VenueBuilding: Equatable, Identifiable {
    let id: String
    let label: String
    let floors: [VenueFloor]
}

/// Snapshot of the venue's buildings/floors plus what's currently active,
/// mirrored from the SDK's `view.currentBuilding`/`view.currentFloor`.
/// Empty `buildings` means the SDK hasn't reported anything yet (see
/// `docs/features/floor-selector.md`).
struct FloorSelection: Equatable {
    let buildings: [VenueBuilding]
    let currentBuildingId: String?
    let currentFloorId: String?

    static let empty = FloorSelection(buildings: [], currentBuildingId: nil, currentFloorId: nil)
}

/// The SDK's 3 building-exploration modes, mirrored from `view.currentExploreMode`.
/// Raw values match the JS SDK's `ExploreMode` type exactly (case-sensitive). See
/// `docs/features/explore-mode.md`.
enum MapExploreMode: String, Equatable {
    case global
    case building
    case floor
}

/// A WGS84 point, as returned by `resolvePoiPosition` for a POI's marker,
/// label, or image position (see `docs/features/simulated-position.md`).
struct GeoPosition: Equatable {
    let latitude: Double
    let longitude: Double
}

/// Result of `loadCustomData`, distinguishing a POI that doesn't exist from
/// one that exists but has no business CustomData (an empty dictionary) —
/// both are normal, non-error states (see `docs/features/custom-data.md`).
enum CustomDataLookup: Equatable {
    case poiNotFound
    case data([String: String])
}

/// One entry of `venue.categories` (`Category = { readonly id: string }`),
/// pushed by `window.MapBridge.getCategories`. `id` is the raw identifier
/// used for filtering/highlighting (a numeric string on this app's shared
/// demo map, e.g. `"9"`) — not itself human-readable — while `label` is the
/// display name resolved JS-side via `venue.translator.translateCategory()`
/// (e.g. `"Shops"`). See `docs/features/category-highlight.md`.
struct MapCategory: Equatable, Identifiable {
    let id: String
    let label: String
}

/// The single dynamic POI tracked at a time by `createDynamicPOI`/
/// `updateDynamicLabelText`/`removeDynamicPOI`, `nil` when none exists.
/// Mirrors the JS side's own `dynamicPoi`/`dynamicLabel` variables in
/// `map.html`. See `docs/features/dynamic-poi-crud.md`.
struct DynamicPOI: Equatable {
    let id: String
    var labelText: String
}

/// Outcome of `createDynamicPOI`, one variant per discriminated result the
/// JS side can report -- see `docs/features/dynamic-poi-crud.md`.
enum CreateDynamicPOIResult: Equatable {
    case created(id: String)
    case duplicate
    case anchorNotFound
    case noPosition
    case bridgeFailure
}

/// Two-way bridge to the SDK running inside `MapWebView`.
///
/// - Native -> JS: calls into `window.MapBridge`, defined in `map.html`, via
///   `evaluateJavaScript`.
/// - JS -> native: implements `WKScriptMessageHandler`, receiving `{type, message?}`
///   payloads posted from `map.html` via `window.webkit.messageHandlers.mapBridge`.
///   See `docs/APP_SDK_COMMUNICATION.md` for the pattern this follows.
final class VisioOneBridge: NSObject, WKScriptMessageHandler, ObservableObject {
    static let messageHandlerName = "mapBridge"

    @Published private(set) var loadState: MapLoadState = .loading

    /// Last POI tapped on the map, `nil` once the reaction panel has been
    /// dismissed. See `docs/features/poi-click.md`.
    @Published private(set) var tappedPOI: TappedPOI?

    /// Buildings/floors of the loaded venue, and which one is currently
    /// active, pushed by the JS side on `ready` and on every SDK
    /// `currentfloorchanged` event (see `docs/features/floor-selector.md`).
    @Published private(set) var floorSelection: FloorSelection = .empty

    /// The venue's current building-exploration mode, mirrored from
    /// `view.currentExploreMode`. Pushed by the JS side once on `ready` and
    /// again on every SDK `exploremodechanged` event -- including changes
    /// triggered by direct camera/map interaction, not just `setExploreMode`
    /// calls from this app (e.g. a click while in `.building` mode
    /// auto-switches the SDK to `.floor`) -- same "SDK event can move state
    /// out from under the app" idiom as `floorSelection` above. Defaults to
    /// `.global` (the SDK's own resting state) until the first push arrives.
    /// See `docs/features/explore-mode.md`.
    @Published private(set) var currentExploreMode: MapExploreMode = .global

    /// Category id (`venue.categories[].id`) currently highlighted via
    /// `highlightCategory`, `nil` when no category is highlighted. Set
    /// optimistically from the Swift side (these are fire-and-forget one-way
    /// calls, see below) rather than round-tripped from JS, and kept on the
    /// bridge itself — not local view state — so it survives the control
    /// sheet being dismissed and reopened. See
    /// `docs/features/category-highlight.md`.
    @Published private(set) var highlightedCategoryId: String?

    /// The single dynamic POI currently tracked (created via
    /// `createDynamicPOI`), `nil` when none exists. Kept on the bridge
    /// itself -- not local view state -- so it survives the control sheet
    /// being dismissed and reopened, same as `highlightedCategoryId` above.
    /// See `docs/features/dynamic-poi-crud.md`.
    @Published private(set) var dynamicPOI: DynamicPOI?

    /// Whether the SDK's own default floor-selector widget is currently
    /// shown alongside the app's native one, driven by the "Show SDK's own
    /// floor selector" toggle on the `native-ui-replacement` screen. Starts
    /// `false` (SDK widget hidden) — the opposite of the SDK's own default —
    /// which `FeatureMapView` enforces with an explicit `setUIPartVisible`
    /// call once the map turns `.ready`, since simply defaulting this
    /// property to `false` wouldn't by itself change anything on the SDK
    /// side. Kept on the bridge itself, not local view state, so it survives
    /// the control sheet being dismissed and reopened, same idiom as
    /// `highlightedCategoryId`/`currentLocale`. See
    /// `docs/features/native-ui-replacement.md`.
    @Published private(set) var isSdkFloorSelectorVisible = false

    /// The venue's current locale (`venue.currentLocale`), `nil` until first
    /// read via `refreshCurrentLocale()`. Kept on the bridge itself -- not
    /// local view state -- so it survives the control sheet being dismissed
    /// and reopened, same as `highlightedCategoryId`/`dynamicPOI` above.
    /// Unlike those two, this is never set optimistically: `setCurrentLocale`
    /// only updates it once the SDK's own `venue.setCurrentLocale()` promise
    /// resolves. See `docs/features/runtime-locale.md`.
    @Published private(set) var currentLocale: String?

    /// The two keys `addSpanishLocale()` adds and reads back via `translate`,
    /// in display order: `'search-for-anything'` is one of the SDK's own
    /// predefined UI keys (see `addLocale`'s TSDoc in the SDK's
    /// `Translator.ts`), showing `addLocale` can override the SDK's own
    /// built-in UI text; `'welcome-message'` is a key the SDK itself has no
    /// built-in meaning for, showing this is a general-purpose key/value
    /// store also usable for the app's own strings. See
    /// `docs/features/add-locale.md`.
    static let addLocaleKeys = ["search-for-anything", "welcome-message"]

    /// Fixed Spanish resources for `addLocaleKeys`, added at runtime via
    /// `venue.translator.addLocale('es', ...)`. See
    /// `docs/features/add-locale.md`.
    private static let spanishResources: [String: String] = [
        "search-for-anything": "Busca lo que quieras",
        "welcome-message": "¡Bienvenido a VisioOne!",
    ]

    /// `nil` until `addSpanishLocale()` succeeds; then one entry per
    /// `addLocaleKeys`, holding `venue.translator.translate(key, 'es')`'s
    /// value -- the primary, always-working proof the round trip succeeded,
    /// regardless of whether any of the SDK's own default UI parts happen to
    /// be visible. Kept on the bridge itself, not local view state, so it
    /// survives the control sheet being dismissed and reopened, same idiom
    /// as `currentLocale`/`highlightedCategoryId`. See
    /// `docs/features/add-locale.md`.
    @Published private(set) var spanishTranslations: [String: String]?

    /// Set by `MapWebView.makeUIView` once the underlying `WKWebView` exists.
    weak var webView: WKWebView?

    /// Recenters the camera on the venue via `view.goToGlobal()`.
    ///
    /// Silent no-op on the JS side if `view` isn't set yet (i.e. before
    /// `createView` has resolved) — see `map.html`.
    func goToGlobal() {
        webView?.evaluateJavaScript("window.MapBridge.goToGlobal()") { _, error in
            if let error {
                print("VisioOneBridge: goToGlobal failed: \(error.localizedDescription)")
            }
        }
    }

    /// Updates a POI's surface color to reflect an occupancy status
    /// (`color: nil` resets the surface to its normal appearance).
    ///
    /// Arguments are JSON-encoded via `JSONSerialization` before being
    /// interpolated into the generated script — never raw string
    /// concatenation, to avoid JS injection (same rule as the other
    /// platforms' native<->JS bridges).
    func updateOccupancy(planId: String, color: String?) {
        guard let webView else { return }

        let entry: [String: Any] = ["planId": planId, "color": color ?? NSNull()]
        guard let data = try? JSONSerialization.data(withJSONObject: [entry]),
              let json = String(data: data, encoding: .utf8) else {
            return
        }

        webView.evaluateJavaScript("window.MapBridge.updateOccupancy(\(json))") { _, error in
            if let error {
                print("VisioOneBridge: updateOccupancy failed: \(error.localizedDescription)")
            }
        }
    }

    /// Centers/zooms the camera on a POI by ID via `view.goToPOI()`, and
    /// highlights its surfaces (see `docs/features/goto-poi.md`).
    ///
    /// `poiId` is JSON-encoded before being interpolated into the generated
    /// script, same rule as `updateOccupancy` above — never raw string
    /// concatenation.
    func goToPOI(_ poiId: String) {
        guard let webView else { return }

        guard let data = try? JSONSerialization.data(withJSONObject: poiId, options: [.fragmentsAllowed]),
              let json = String(data: data, encoding: .utf8) else {
            return
        }

        webView.evaluateJavaScript("window.MapBridge.goToPOI(\(json))") { _, error in
            if let error {
                print("VisioOneBridge: goToPOI failed: \(error.localizedDescription)")
            }
        }
    }

    /// Clears whatever highlight `goToPOI` left on the map, without moving
    /// the camera (see `docs/features/goto-poi.md`).
    func clearPOI() {
        webView?.evaluateJavaScript("window.MapBridge.clearPOI()") { _, error in
            if let error {
                print("VisioOneBridge: clearPOI failed: \(error.localizedDescription)")
            }
        }
    }

    /// Switches floor within the currently active building via
    /// `view.goToFloor()` (see `docs/features/floor-selector.md`).
    ///
    /// `floorId` is JSON-encoded before being interpolated into the
    /// generated script, same rule as `goToPOI` above.
    func goToFloor(_ floorId: String) {
        guard let webView else { return }

        guard let data = try? JSONSerialization.data(withJSONObject: floorId, options: [.fragmentsAllowed]),
              let json = String(data: data, encoding: .utf8) else {
            return
        }

        webView.evaluateJavaScript("window.MapBridge.goToFloor(\(json))") { _, error in
            if let error {
                print("VisioOneBridge: goToFloor failed: \(error.localizedDescription)")
            }
        }
    }

    /// Switches building via `view.goToBuilding()`, which resolves to that
    /// building's default floor (see `docs/features/floor-selector.md`).
    func goToBuilding(_ buildingId: String) {
        guard let webView else { return }

        guard let data = try? JSONSerialization.data(withJSONObject: buildingId, options: [.fragmentsAllowed]),
              let json = String(data: data, encoding: .utf8) else {
            return
        }

        webView.evaluateJavaScript("window.MapBridge.goToBuilding(\(json))") { _, error in
            if let error {
                print("VisioOneBridge: goToBuilding failed: \(error.localizedDescription)")
            }
        }
    }

    /// Sets the venue's building-exploration mode via `view.currentExploreMode`
    /// (see `docs/features/explore-mode.md`). `mode` is a Swift enum value
    /// computed on this side (never raw user text), so its raw value is
    /// interpolated directly into the generated script rather than
    /// JSON-encoded, same rule as the plain booleans elsewhere in this file
    /// (e.g. `setCameraLockOnPosition`). Fire-and-forget: `currentExploreMode`
    /// itself is only ever updated from the JS side's `exploreModeChanged`
    /// bridge message (see `userContentController` below), never
    /// optimistically here, since the SDK can auto-switch out of `.building`
    /// mode on its own (a click switches it to `.floor`) and the native UI
    /// must reflect whatever the SDK actually lands on, not what was
    /// requested.
    func setExploreMode(_ mode: MapExploreMode) {
        webView?.evaluateJavaScript("window.MapBridge.setExploreMode('\(mode.rawValue)')") { _, error in
            if let error {
                print("VisioOneBridge: setExploreMode failed: \(error.localizedDescription)")
            }
        }
    }

    /// Computes a route between two POIs (by ID) and displays it, via
    /// `venue.computeNavigation()` + `venue.createNavigationTrace()` +
    /// `view.setCurrentNavigationTrace()` (see
    /// `docs/features/compute-navigation.md`). Computing a new route while
    /// one is already displayed replaces it automatically — no explicit
    /// "clear" is needed.
    ///
    /// The request is JSON-encoded via `JSONSerialization` before being
    /// interpolated into the generated script, same rule as the other
    /// bridge methods above.
    func computeNavigation(origin: String, destination: String, isAccessible: Bool) {
        guard let webView else { return }

        let request: [String: Any] = ["origin": origin, "destination": destination, "isAccessible": isAccessible]
        guard let data = try? JSONSerialization.data(withJSONObject: request),
              let json = String(data: data, encoding: .utf8) else {
            return
        }

        webView.evaluateJavaScript("window.MapBridge.computeNavigation(\(json))") { _, error in
            if let error {
                print("VisioOneBridge: computeNavigation failed: \(error.localizedDescription)")
            }
        }
    }

    /// Shows/hides one of the SDK's own default UI overlays via
    /// `view.setUIPartVisible()` (see `docs/features/ui-part-visibility.md`).
    ///
    /// `uiPart` must be one of the SDK's exact, case-sensitive `UIPart`
    /// values (`floorSelector`, `navigation`, `poiDetails`, `search`,
    /// `userTracking`) — see `MapUIPart` in `FeatureOverlays.swift`, which is
    /// the only caller. It's JSON-encoded before being interpolated into the
    /// generated script, same rule as the other bridge methods above.
    func setUIPartVisible(_ uiPart: String, isVisible: Bool) {
        guard let webView else { return }

        guard let data = try? JSONSerialization.data(withJSONObject: uiPart, options: [.fragmentsAllowed]),
              let json = String(data: data, encoding: .utf8) else {
            return
        }

        webView.evaluateJavaScript("window.MapBridge.setUIPartVisible(\(json), \(isVisible))") { _, error in
            if let error {
                print("VisioOneBridge: setUIPartVisible failed: \(error.localizedDescription)")
            }
        }
    }

    /// Shows/hides the SDK's own default floor-selector widget by delegating
    /// to `setUIPartVisible('floorSelector', isVisible:)` above, additionally
    /// mirroring the result into `isSdkFloorSelectorVisible` so the
    /// `native-ui-replacement` toggle reflects the current state after the
    /// control sheet is dismissed and reopened. The only caller of
    /// `setUIPartVisible` for that specific part outside of
    /// `UIPartVisibilityOverlay`'s generic 5-switch panel. See
    /// `docs/features/native-ui-replacement.md`.
    func setSdkFloorSelectorVisible(_ isVisible: Bool) {
        isSdkFloorSelectorVisible = isVisible
        setUIPartVisible("floorSelector", isVisible: isVisible)
    }

    /// Resolves a POI's WGS84 position by ID via `window.MapBridge.resolvePoiPosition`
    /// (see `docs/features/simulated-position.md`). Unlike the other bridge
    /// methods, this one reads `evaluateJavaScript`'s own return value
    /// instead of pushing a message through `WKScriptMessageHandler` — the
    /// lookup is a synchronous, side-effect-free JS computation (an array
    /// `find` + reading a nested `position`), so the existing native<->JS
    /// call already carries the answer back; no extra message channel is
    /// needed. Returns `nil` if the POI id doesn't exist, or if it has no
    /// marker/label/image to read a position from — both cases are
    /// indistinguishable "POI not found" to the caller, matching the spec.
    func resolvePoiPosition(_ poiId: String) async -> GeoPosition? {
        guard let webView else { return nil }

        guard let data = try? JSONSerialization.data(withJSONObject: poiId, options: [.fragmentsAllowed]),
              let json = String(data: data, encoding: .utf8) else {
            return nil
        }

        return await withCheckedContinuation { continuation in
            webView.evaluateJavaScript("window.MapBridge.resolvePoiPosition(\(json))") { result, error in
                if let error {
                    print("VisioOneBridge: resolvePoiPosition failed: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                    return
                }
                guard let payload = result as? [String: Any],
                      let latitude = payload["latitude"] as? Double,
                      let longitude = payload["longitude"] as? Double else {
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: GeoPosition(latitude: latitude, longitude: longitude))
            }
        }
    }

    /// Injects/updates a simulated tracked position + its accuracy circle via
    /// `view.injectTrackedPosition()`, turning on `view.allowTracking` first
    /// (done JS-side, on every call — see `map.html`). Meant to be called
    /// repeatedly on a timer by the caller (see `SimulatedPositionOverlay`);
    /// this method itself is stateless. `latitude`/`longitude`/
    /// `precisionCircleRadius` are plain `Double`s computed on the Swift
    /// side (never raw user text), so they're interpolated directly into
    /// the generated script rather than JSON-encoded, same as the boolean
    /// in `setUIPartVisible` above.
    func injectTrackedPosition(latitude: Double, longitude: Double, precisionCircleRadius: Double) {
        webView?.evaluateJavaScript(
            "window.MapBridge.injectTrackedPosition(\(latitude), \(longitude), \(precisionCircleRadius))"
        ) { _, error in
            if let error {
                print("VisioOneBridge: injectTrackedPosition failed: \(error.localizedDescription)")
            }
        }
    }

    /// Removes the simulated tracked position from the map via
    /// `view.allowTracking = false` — the SDK has no dedicated "stop"
    /// method, this is how the marker/accuracy circle is cleared (see
    /// `docs/features/simulated-position.md`).
    func stopTrackedPosition() {
        webView?.evaluateJavaScript("window.MapBridge.stopTrackedPosition()") { _, error in
            if let error {
                print("VisioOneBridge: stopTrackedPosition failed: \(error.localizedDescription)")
            }
        }
    }

    /// Locks/unlocks the camera onto the currently tracked position via
    /// `view.lockCameraPositionOnTracking` (see
    /// `docs/features/camera-lock-on-position.md`). Only has a visible
    /// effect once `view.allowTracking` is already `true` (i.e. a
    /// simulated-position loop is running, see `injectTrackedPosition`
    /// above) — per the SDK's own doc comment, setting this while tracking
    /// is off is a harmless no-op, not an exception (unlike
    /// `injectTrackedPosition`, which does throw when `allowTracking` is
    /// `false`), so no extra guard is needed on the Swift side either.
    ///
    /// `locked` is a plain `Bool` computed on the Swift side (never raw
    /// user text), so it's interpolated directly into the generated script
    /// rather than JSON-encoded — same rule as the boolean in
    /// `setUIPartVisible` above.
    func setCameraLockOnPosition(_ locked: Bool) {
        webView?.evaluateJavaScript("window.MapBridge.setCameraLockOnPosition(\(locked))") { _, error in
            if let error {
                print("VisioOneBridge: setCameraLockOnPosition failed: \(error.localizedDescription)")
            }
        }
    }

    /// Makes a POI's surface(s) clickable via `venue.updateSurface()`'s
    /// `isInteractive` option, letting the SDK itself swap the displayed
    /// color on hover/tap (`hoverColor`/`selectionColor`) — no click
    /// listener is needed on either side of the bridge for that part (see
    /// `docs/features/clickable-surface.md`). Disabling resets the base
    /// color to `'initial'` so the surface doesn't stay stuck on the custom
    /// color set while enabled.
    ///
    /// `placeId` is JSON-encoded before being interpolated into the
    /// generated script, same rule as `goToPOI` above; `isInteractive` is a
    /// plain `Bool` computed on the Swift side (never raw user text), so
    /// it's interpolated directly, same as the boolean in
    /// `setUIPartVisible`.
    func setSurfaceInteractive(_ placeId: String, isInteractive: Bool) {
        guard let webView else { return }

        guard let data = try? JSONSerialization.data(withJSONObject: placeId, options: [.fragmentsAllowed]),
              let json = String(data: data, encoding: .utf8) else {
            return
        }

        webView.evaluateJavaScript("window.MapBridge.setSurfaceInteractive(\(json), \(isInteractive))") { _, error in
            if let error {
                print("VisioOneBridge: setSurfaceInteractive failed: \(error.localizedDescription)")
            }
        }
    }

    /// Refreshes the venue's CustomData cache via `venue.refreshCustomData()`,
    /// then reads the given POI's data via `venue.getPOICustomData()` in the
    /// same JS call (see `docs/features/custom-data.md`). Unlike the other
    /// bridge methods, `refreshCustomData()` is an SDK call that awaits a
    /// network round trip, so `window.MapBridge.loadCustomData` is itself an
    /// `async` function — this is the only bridge method that needs to wait
    /// for a JS `Promise` to settle before reading a value back, hence
    /// `WKWebView.callAsyncJavaScript` rather than a plain
    /// `evaluateJavaScript` string (see `docs/APP_SDK_COMMUNICATION.md`,
    /// section 1.2, for why `evaluateJavaScript` alone doesn't wait on a
    /// returned promise).
    ///
    /// Returns `nil` on a bridge/JS failure (logged, not surfaced further);
    /// `.poiNotFound` when `poiId` doesn't resolve to a POI in the loaded
    /// venue; `.data(_)` otherwise, where the dictionary is `{}` (never
    /// `nil`) when the POI has no CustomData.
    func loadCustomData(_ poiId: String) async -> CustomDataLookup? {
        guard let webView else { return nil }

        return await withCheckedContinuation { continuation in
            webView.callAsyncJavaScript(
                "return await window.MapBridge.loadCustomData(poiId);",
                arguments: ["poiId": poiId],
                in: nil,
                in: .page
            ) { result in
                switch result {
                case .success(let value):
                    guard let payload = value as? [String: Any],
                          let found = payload["found"] as? Bool else {
                        continuation.resume(returning: nil)
                        return
                    }
                    guard found else {
                        continuation.resume(returning: .poiNotFound)
                        return
                    }
                    continuation.resume(returning: .data(payload["data"] as? [String: String] ?? [:]))
                case .failure(let error):
                    print("VisioOneBridge: loadCustomData failed: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                }
            }
        }
    }

    /// Reads the venue's full category list via `window.MapBridge.getCategories`
    /// (see `docs/features/category-highlight.md`). Like `resolvePoiPosition`,
    /// this reads a synchronous JS computation straight from
    /// `evaluateJavaScript`'s own return value rather than through
    /// `WKScriptMessageHandler` — `venue.categories` is data the SDK already
    /// holds once the venue is loaded, no promise involved — so a plain
    /// `evaluateJavaScript` call (wrapped here in `withCheckedContinuation`
    /// purely so callers can `await` it) is the cleanest fit, unlike
    /// `loadCustomData` above which genuinely awaits a JS `Promise` and needs
    /// `callAsyncJavaScript`. Returns `nil` on a bridge/JS failure; an empty
    /// array is a normal (if unlikely) "no categories on this venue" result,
    /// not an error.
    func getCategories() async -> [MapCategory]? {
        guard let webView else { return nil }

        return await withCheckedContinuation { continuation in
            webView.evaluateJavaScript("window.MapBridge.getCategories()") { result, error in
                if let error {
                    print("VisioOneBridge: getCategories failed: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                    return
                }
                guard let payload = result as? [[String: Any]] else {
                    continuation.resume(returning: nil)
                    return
                }
                let categories = payload.compactMap { entry -> MapCategory? in
                    guard let id = entry["id"] as? String else { return nil }
                    return MapCategory(id: id, label: entry["label"] as? String ?? id)
                }
                continuation.resume(returning: categories)
            }
        }
    }

    /// Highlights every POI belonging to `categoryId` via
    /// `venue.pois.filter(...)` + `venue.updateSurface()`, reverting whatever
    /// category was previously highlighted first so only one is ever
    /// highlighted at a time (see `docs/features/category-highlight.md`).
    /// Fire-and-forget, like `setSurfaceInteractive` above — no response is
    /// needed, so `highlightedCategoryId` is updated optimistically here
    /// rather than waiting on a round trip.
    ///
    /// `categoryId` is JSON-encoded before being interpolated into the
    /// generated script, same rule as the other bridge methods that take a
    /// caller-provided string.
    func highlightCategory(_ categoryId: String) {
        guard let webView else { return }

        guard let data = try? JSONSerialization.data(withJSONObject: categoryId, options: [.fragmentsAllowed]),
              let json = String(data: data, encoding: .utf8) else {
            return
        }

        highlightedCategoryId = categoryId
        webView.evaluateJavaScript("window.MapBridge.highlightCategory(\(json))") { _, error in
            if let error {
                print("VisioOneBridge: highlightCategory failed: \(error.localizedDescription)")
            }
        }
    }

    /// Reverts whatever `highlightCategory` last applied (see
    /// `docs/features/category-highlight.md`). Fire-and-forget, same as
    /// `highlightCategory` above.
    func clearCategoryHighlight() {
        guard let webView else { return }

        highlightedCategoryId = nil
        webView.evaluateJavaScript("window.MapBridge.clearCategoryHighlight()") { _, error in
            if let error {
                print("VisioOneBridge: clearCategoryHighlight failed: \(error.localizedDescription)")
            }
        }
    }

    /// Creates a bare POI (id/floor/categories only) via `venue.createPOI()`
    /// and attaches a visible `Label` to it via `venue.createLabel()`,
    /// copying its position from an existing "anchor" POI's first label or
    /// marker (see `docs/features/dynamic-poi-crud.md`). Like
    /// `loadCustomData` above, this is called via `WKWebView.callAsyncJavaScript`
    /// rather than a plain `evaluateJavaScript` string, so the result --
    /// success, a duplicate id (`venue.createPOI` throws `POIAlreadyExistsError`),
    /// an unresolved anchor, or an anchor with no position to copy -- comes
    /// back as a normal, awaited value rather than a thrown JS exception.
    ///
    /// On success, updates `dynamicPOI` so the UI reflects the newly tracked
    /// POI; every other outcome leaves `dynamicPOI` untouched.
    func createDynamicPOI(newId: String, anchorId: String, labelText: String) async -> CreateDynamicPOIResult {
        guard let webView else { return .bridgeFailure }

        return await withCheckedContinuation { continuation in
            webView.callAsyncJavaScript(
                "return await window.MapBridge.createDynamicPOI(newId, anchorId, labelText);",
                arguments: ["newId": newId, "anchorId": anchorId, "labelText": labelText],
                in: nil,
                in: .page
            ) { [weak self] result in
                switch result {
                case .success(let value):
                    guard let payload = value as? [String: Any], let status = payload["status"] as? String else {
                        continuation.resume(returning: .bridgeFailure)
                        return
                    }
                    switch status {
                    case "created":
                        guard let id = payload["id"] as? String else {
                            continuation.resume(returning: .bridgeFailure)
                            return
                        }
                        self?.dynamicPOI = DynamicPOI(id: id, labelText: labelText)
                        continuation.resume(returning: .created(id: id))
                    case "duplicate":
                        continuation.resume(returning: .duplicate)
                    case "anchorNotFound":
                        continuation.resume(returning: .anchorNotFound)
                    case "noPosition":
                        continuation.resume(returning: .noPosition)
                    default:
                        continuation.resume(returning: .bridgeFailure)
                    }
                case .failure(let error):
                    print("VisioOneBridge: createDynamicPOI failed: \(error.localizedDescription)")
                    continuation.resume(returning: .bridgeFailure)
                }
            }
        }
    }

    /// Updates the tracked dynamic POI's label text via `venue.updateLabel()`
    /// -- the real "edit" story for a dynamic POI, since `venue.updatePOI()`
    /// itself can only ever touch categories (see
    /// `docs/features/dynamic-poi-crud.md`). Updates `dynamicPOI` optimistically,
    /// same fire-and-forget idiom as `highlightCategory` above. No-op if
    /// nothing is currently tracked.
    ///
    /// `text` is JSON-encoded before being interpolated into the generated
    /// script, same rule as the other bridge methods that take a
    /// caller-provided string.
    func updateDynamicLabelText(_ text: String) {
        guard let webView, dynamicPOI != nil else { return }

        guard let data = try? JSONSerialization.data(withJSONObject: text, options: [.fragmentsAllowed]),
              let json = String(data: data, encoding: .utf8) else {
            return
        }

        dynamicPOI?.labelText = text
        webView.evaluateJavaScript("window.MapBridge.updateDynamicLabelText(\(json))") { _, error in
            if let error {
                print("VisioOneBridge: updateDynamicLabelText failed: \(error.localizedDescription)")
            }
        }
    }

    /// Removes the tracked dynamic POI via `venue.removePOI()`, which
    /// cascades to remove its attached label automatically -- no separate
    /// label removal call is needed (see `docs/features/dynamic-poi-crud.md`).
    /// Clears `dynamicPOI` optimistically. No-op if nothing is currently
    /// tracked.
    func removeDynamicPOI() {
        guard let webView, dynamicPOI != nil else { return }

        dynamicPOI = nil
        webView.evaluateJavaScript("window.MapBridge.removeDynamicPOI()") { _, error in
            if let error {
                print("VisioOneBridge: removeDynamicPOI failed: \(error.localizedDescription)")
            }
        }
    }

    /// Reads the venue's current locale via `window.MapBridge.getCurrentLocale`
    /// and stores it in `currentLocale` (see `docs/features/runtime-locale.md`).
    /// Like `getCategories`/`resolvePoiPosition`, this reads a synchronous JS
    /// property straight from `evaluateJavaScript`'s own return value, no
    /// promise involved.
    func refreshCurrentLocale() async {
        guard let webView else { return }

        let result: String? = await withCheckedContinuation { continuation in
            webView.evaluateJavaScript("window.MapBridge.getCurrentLocale()") { result, error in
                if let error {
                    print("VisioOneBridge: getCurrentLocale failed: \(error.localizedDescription)")
                    continuation.resume(returning: nil)
                    return
                }
                continuation.resume(returning: result as? String)
            }
        }
        if let result {
            currentLocale = result
        }
    }

    /// Switches the map's displayed locale via `venue.setCurrentLocale()`,
    /// which returns a Promise the SDK itself awaits before re-rendering
    /// every POI/label's text (and any current View UI) for the new locale --
    /// no manual re-fetch of POI data is needed on this side (see
    /// `docs/features/runtime-locale.md`). Unlike the fire-and-forget bridge
    /// calls above (`highlightCategory`, `setSurfaceInteractive`, ...),
    /// `currentLocale` is only updated here once that promise actually
    /// resolves, via `callAsyncJavaScript` -- same idiom as `loadCustomData`/
    /// `createDynamicPOI` -- rather than optimistically before the call.
    ///
    /// Returns `false` on a bridge/JS failure (logged, not surfaced further),
    /// leaving `currentLocale` untouched.
    @discardableResult
    func setCurrentLocale(_ locale: String) async -> Bool {
        guard let webView else { return false }

        return await withCheckedContinuation { continuation in
            webView.callAsyncJavaScript(
                "return await window.MapBridge.setCurrentLocale(locale);",
                arguments: ["locale": locale],
                in: nil,
                in: .page
            ) { [weak self] result in
                switch result {
                case .success:
                    self?.currentLocale = locale
                    continuation.resume(returning: true)
                case .failure(let error):
                    print("VisioOneBridge: setCurrentLocale failed: \(error.localizedDescription)")
                    continuation.resume(returning: false)
                }
            }
        }
    }

    /// Adds the `'es'` locale at runtime via
    /// `window.MapBridge.addLocale`/`venue.translator.addLocale()` -- a
    /// locale never authored in VisioMapEditor for this map -- using the
    /// fixed `spanishResources` dictionary, then reads each of
    /// `addLocaleKeys` back via `translate(_:)` below to populate
    /// `spanishTranslations`. Both `addLocale` and `translate` are
    /// synchronous SDK calls (no `Promise` involved, unlike
    /// `setCurrentLocale`), but this is still `async` so the second step
    /// only runs once `addLocale`'s own `evaluateJavaScript` completion has
    /// actually returned. See `docs/features/add-locale.md`.
    func addSpanishLocale() async {
        guard let webView else { return }

        guard let data = try? JSONSerialization.data(withJSONObject: Self.spanishResources),
              let resourcesJson = String(data: data, encoding: .utf8) else {
            return
        }

        let didAdd: Bool = await withCheckedContinuation { continuation in
            webView.evaluateJavaScript("window.MapBridge.addLocale('es', \(resourcesJson))") { _, error in
                if let error {
                    print("VisioOneBridge: addLocale failed: \(error.localizedDescription)")
                    continuation.resume(returning: false)
                    return
                }
                continuation.resume(returning: true)
            }
        }
        guard didAdd else { return }

        var results: [String: String] = [:]
        for key in Self.addLocaleKeys {
            results[key] = await translateSpanish(key)
        }
        spanishTranslations = results
    }

    /// Reads a single key back via `window.MapBridge.translate`/
    /// `venue.translator.translate(key, 'es')`. See
    /// `docs/features/add-locale.md`.
    private func translateSpanish(_ key: String) async -> String {
        guard let webView else { return "" }

        guard let data = try? JSONSerialization.data(withJSONObject: key, options: [.fragmentsAllowed]),
              let json = String(data: data, encoding: .utf8) else {
            return ""
        }

        return await withCheckedContinuation { continuation in
            webView.evaluateJavaScript("window.MapBridge.translate(\(json), 'es')") { result, error in
                if let error {
                    print("VisioOneBridge: translate failed: \(error.localizedDescription)")
                    continuation.resume(returning: "")
                    return
                }
                continuation.resume(returning: result as? String ?? "")
            }
        }
    }

    /// Resets to `.loading` and reloads the page, rather than leaving the UI
    /// stuck on `.error` until the next JS message arrives.
    func reload() {
        loadState = .loading
        webView?.reload()
    }

    /// Resets the reaction panel's source of truth, e.g. once the user
    /// dismisses it — so tapping the same POI again is still detected as a
    /// change (`tappedPOI` going `nil` -> non-`nil`).
    func clearTappedPOI() {
        tappedPOI = nil
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        guard message.name == Self.messageHandlerName,
              let body = message.body as? [String: Any],
              let type = body["type"] as? String else { return }

        switch type {
        case "ready":
            loadState = .ready
        case "error":
            loadState = .error(body["message"] as? String ?? "Erreur inconnue du SDK VisioOne")
        case "poiSelected":
            guard let payload = body["message"] as? [String: Any],
                  let id = payload["id"] as? String else { return }
            tappedPOI = TappedPOI(id: id, name: payload["name"] as? String)
        case "floorsChanged":
            guard let payload = body["message"] as? [String: Any] else { return }
            floorSelection = Self.parseFloorSelection(payload)
        case "exploreModeChanged":
            guard let payload = body["message"] as? [String: Any],
                  let rawMode = payload["currentExploreMode"] as? String,
                  let mode = MapExploreMode(rawValue: rawMode) else { return }
            currentExploreMode = mode
        default:
            break
        }
    }

    /// Parses the `floorsChanged` payload sent by `map.html`'s
    /// `sendFloorsState()` (see `docs/features/floor-selector.md`). Malformed
    /// entries are skipped rather than failing the whole payload, so a
    /// single unexpected building doesn't blank out the rest of the list.
    private static func parseFloorSelection(_ payload: [String: Any]) -> FloorSelection {
        let rawBuildings = payload["buildings"] as? [[String: Any]] ?? []
        let buildings: [VenueBuilding] = rawBuildings.compactMap { raw in
            guard let id = raw["id"] as? String, let label = raw["label"] as? String else { return nil }
            let rawFloors = raw["floors"] as? [[String: Any]] ?? []
            let floors: [VenueFloor] = rawFloors.compactMap { rawFloor in
                guard let floorId = rawFloor["id"] as? String, let floorLabel = rawFloor["label"] as? String else { return nil }
                return VenueFloor(id: floorId, label: floorLabel)
            }
            return VenueBuilding(id: id, label: label, floors: floors)
        }

        return FloorSelection(
            buildings: buildings,
            currentBuildingId: payload["currentBuildingId"] as? String,
            currentFloorId: payload["currentFloorId"] as? String
        )
    }
}

/// `WKUserContentController.add(_:name:)` strongly retains its handler — registering
/// this proxy instead of `VisioOneBridge` directly avoids a retain cycle with the web view.
final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
    private weak var target: WKScriptMessageHandler?

    init(target: WKScriptMessageHandler) {
        self.target = target
    }

    func userContentController(_ userContentController: WKUserContentController, didReceive message: WKScriptMessage) {
        target?.userContentController(userContentController, didReceive: message)
    }
}
