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
