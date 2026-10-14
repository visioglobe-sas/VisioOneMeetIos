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

/// The SDK's 3 `Image` orientation modes (`OrientationType`). Raw values
/// match the JS SDK's string literals exactly -- `venue.createImage` throws
/// `"Invalid orientation type"` on anything else. See
/// `docs/features/3d-icon-marker.md`.
enum IconOrientation: String, CaseIterable, Identifiable {
    /// Flat on the ground, fixed heading (`rotation`).
    case fixed
    /// Flat on the ground, turning to face the camera.
    case flat
    /// Billboard, always facing the camera.
    case facing

    var id: String { rawValue }
}

/// Outcome of `placeIcon`, one variant per discriminated result the JS side
/// can report -- see `docs/features/3d-icon-marker.md`.
enum PlaceIconResult: Equatable {
    case placed
    case poiNotFound
    case noPosition
    case failure(String)
}

/// Color choices offered for the custom text label. Raw values are the hex
/// strings passed as-is to `venue.createLabel`/`venue.updateLabel`'s
/// `color` (hex, `rgb()` or `hsl()` only -- anything else throws). See
/// `docs/features/custom-text-label.md`.
enum TextLabelColor: String, CaseIterable, Identifiable {
    case red = "#E53935"
    case green = "#43A047"
    case blue = "#1E88E5"
    case dark = "#212121"

    var id: String { rawValue }
}

/// Size presets for the custom text label, in meters. Width and height are
/// always sent together: the SDK defaults `height` to `width` on create, and
/// `updateLabel(label, { width })` alone also resets `height` to `width`.
/// See `docs/features/custom-text-label.md`.
enum TextLabelSize: String, CaseIterable, Identifiable {
    case small
    case medium
    case large

    var id: String { rawValue }

    var width: Double {
        switch self {
        case .small: return 10
        case .medium: return 16
        case .large: return 22
        }
    }

    var height: Double {
        switch self {
        case .small: return 2
        case .medium: return 3
        case .large: return 4
        }
    }
}

/// Outcome of `placeTextLabel`/`updateTextLabelText`, one variant per
/// discriminated result the JS side can report -- see
/// `docs/features/custom-text-label.md`.
enum TextLabelResult: Equatable {
    case success
    case textRequired
    case poiNotFound
    case noPosition
    case noLabel
    case failure(String)
}

/// Outcome of `placeHtmlBadge`/`updateHtmlBadgeText`, one variant per
/// discriminated result the JS side can report -- see
/// `docs/features/html-overlay-marker.md`.
enum HtmlBadgeResult: Equatable {
    case success
    case textRequired
    case poiNotFound
    case noPosition
    case noBadge
    case failure(String)
}

/// Accent color choices for the SDK's own UI buttons (POI card "Go", "Add a
/// step"...). Raw values are the hex strings assigned as-is to
/// `view.accentColor` (hex, `rgba()` or `hsl()` only -- anything else
/// throws). `.blue` is the SDK default. See `docs/features/custom-theme.md`.
enum ThemeAccentColor: String, CaseIterable, Identifiable {
    case blue = "#0094F0"
    case red = "#E53935"
    case green = "#43A047"
    case purple = "#8E24AA"

    var id: String { rawValue }
}

/// Text color choices for those same SDK buttons, assigned as-is to
/// `view.textAccentColor`. `.white` is the SDK default. See
/// `docs/features/custom-theme.md`.
enum ThemeTextAccentColor: String, CaseIterable, Identifiable {
    case white = "#FFFFFF"
    case yellow = "#FFEB3B"
    case black = "#212121"

    var id: String { rawValue }
}

/// Outcome of `resolveZonePolygon`, one variant per discriminated result the
/// JS side can report -- see `docs/features/geofencing.md`.
enum ResolveZoneResult: Equatable {
    case notFound
    case noSurface
    case zone(positions: [GeoPosition])
    case bridgeFailure
}

/// Colors applicable to an already-displayed navigation trace via
/// `venue.updateNavigationTrace()`. Mirrors the SDK's
/// `NavigationTraceUpdateOptions` colors-only surface -- `textureRepeat`/
/// `animationSpeed` are omitted since they only affect the `'textured'`
/// `displayMode`, which can't be changed after `createNavigationTrace()`.
/// See `docs/features/custom-navigation-trace.md`.
struct NavigationTraceColors: Equatable {
    let progressColor: String
    let progressOutlineColor: String
    let progressFutureColor: String
    let previewColor: String
    let previewOutlineColor: String
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

    /// Anchor POI id the 3D icon is currently placed on, `nil` when none is
    /// placed. Kept on the bridge itself -- not local view state -- so it
    /// survives the control sheet being dismissed and reopened, same as
    /// `dynamicPOI` above. See `docs/features/3d-icon-marker.md`.
    @Published private(set) var placedIconAnchorId: String?

    /// Orientation currently selected for the 3D icon, applied on the next
    /// `placeIcon` and live (via `venue.updateImage`) to an already placed
    /// one. Defaults to `.facing`. See `docs/features/3d-icon-marker.md`.
    @Published private(set) var iconOrientation: IconOrientation = .facing

    /// Anchor POI id the custom text label is currently placed on, `nil`
    /// when none is placed, plus that label's current text. Kept on the
    /// bridge itself -- not local view state -- so they survive the control
    /// sheet being dismissed and reopened, same as `placedIconAnchorId`
    /// above. See `docs/features/custom-text-label.md`.
    @Published private(set) var placedTextLabelAnchorId: String?
    @Published private(set) var placedTextLabelText: String?

    /// Style currently selected for the custom text label, applied on the
    /// next `placeTextLabel` and live to an already placed one.
    @Published private(set) var textLabelColor: TextLabelColor = .red
    @Published private(set) var textLabelSize: TextLabelSize = .medium
    @Published private(set) var textLabelRotation: Int = 0

    /// Anchor POI id the HTML badge is currently placed on, `nil` when none
    /// is placed, plus that badge's current text, whether it's currently
    /// shown, and how many times it was tapped since the last successful
    /// place (pushed by the JS side's `htmlBadgeTapped` message). Kept on
    /// the bridge itself -- not local view state -- so they survive the
    /// control sheet being dismissed and reopened (the badge can only be
    /// tapped with the sheet closed). See `docs/features/html-overlay-marker.md`.
    @Published private(set) var placedHtmlBadgeAnchorId: String?
    @Published private(set) var placedHtmlBadgeText: String?
    @Published private(set) var isHtmlBadgeVisible = true
    @Published private(set) var htmlBadgeTapCount = 0

    /// Key under which the JS side stores the single `Image` this demo
    /// places (`iconImages` in `map.html`) -- `Image` isn't
    /// JSON-serializable, so only this key crosses the bridge.
    private static let iconImageId = "3d-icon-marker"

    /// 96x96 PNG (blue disc + white star) passed as `createImage`'s `url`,
    /// identical on every VisioOneMeet platform. Any image URL works,
    /// including `https://` ones. See `docs/features/3d-icon-marker.md`.
    static let iconDataURL = "data:image/png;base64,iVBORw0KGgoAAAANSUhEUgAAAGAAAABgCAYAAADimHc4AAACBklEQVR42u3dWW4CMRBFUVbLarOn5JsIqRlsv6FuSfmE0O+IwS7bfbtR1GXdf34/+qMOhg2KcehgGIU+HsMt+DEQ7sHXQqQFXwWRHn4sQkvwkRCt4dsjtAdvDTEtfCuEqeFbIAgv/H/NQzAKfx6CYfhzEIzD70cQf+FFAGxFAEAIEBJ+J4LB7+04gKUIAAgBTEackQBfI4SG34MAgBDAaMIrHuAjBACEAGZTvhUAbyEAIAQwbHrUALyEAAAAcwGMe68V4V8iHAjJHeAI7mqAb0oNcOK1vwYgCP+di1E/334EMcDVRSmewx5gd60COPk6K94Bzy7u1OP4CAqrNQCCQdJ4gAcE0Uh1dPgrASYirB0Ri+dsRoa/A6AdYt+ckNksZn3wpwDSIc7NiprP69cFrwJwBdH3BUo6YLlN+qI2ZGZ7EgAA+AgqD99/ueKA8K0Q0veAxSMk7v+tQnABULQrvQZhQgBVv9gCQb00cXVoUQgOa0MBEALsCitvFlSEMBpAvT9gd0g5TRgATAGMe8Ru/ydul+TJULIBNiGMBlDvlFcE4rkGSISgCsICwOG0FGUIuQDCdaM121ydTs1S/wrJDP8gQN3pu44nJzo1RXLC56h6Ts4FAAROUCd8ELiLBuGDwJ2UCB8E7qhH8BMR4orgQZgdfjJEbRE8ELODd8KgBBjUQRSKuqo/fm7G7BpJ/VcAAAAASUVORK5CYII="

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

    /// The SDK's own default `baseURL` (`LoadOptions.baseURL`'s default) --
    /// the root every other feature implicitly loads map data from. Kept
    /// here (rather than local view state) so it survives the control sheet
    /// being dismissed and reopened, same idiom as `currentLocale`/
    /// `highlightedCategoryId`. Only the `custom-base-url` feature reads or
    /// changes this -- see `docs/features/custom-base-url.md`.
    @Published private(set) var baseURL = "https://mapserver.visioglobe.com/"

    /// Scene themes registered on the view (`view.themes`), read once via
    /// `loadThemes()` -- empty until then. See `docs/features/custom-theme.md`.
    @Published private(set) var themes: [String] = []

    /// Theme / accent colors currently applied, kept on the bridge itself --
    /// not local view state -- so they survive the control sheet being
    /// dismissed and reopened. The SDK has no current-theme getter, so the
    /// theme is tracked here, starting at the SDK default `"day"`. See
    /// `docs/features/custom-theme.md`.
    @Published private(set) var currentTheme = VisioOneBridge.defaultTheme
    @Published private(set) var themeAccentColor: ThemeAccentColor = .blue
    @Published private(set) var themeTextAccentColor: ThemeTextAccentColor = .white

    static let defaultTheme = "day"

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

    /// Restyles the currently displayed navigation trace (if any) via
    /// `venue.updateNavigationTrace()` (see
    /// `docs/features/custom-navigation-trace.md`). Colors only -- there is
    /// no way to change `displayMode`/`thickness` after
    /// `createNavigationTrace()`. No-op JS-side if `computeNavigation`
    /// hasn't created a trace yet (see `map.html`).
    ///
    /// `colors` is JSON-encoded via `JSONSerialization` before being
    /// interpolated into the generated script, same rule as the other
    /// bridge methods above.
    ///
    /// The JS side swallows an internal SDK `TypeError` this call is known
    /// to throw against this app's shared demo venue (see `map.html`), so
    /// the completion handler here only ever reports an actual bridge/JSON
    /// failure, never that quirk.
    func updateNavigationTrace(_ colors: NavigationTraceColors) {
        guard let webView else { return }

        let options: [String: Any] = [
            "progressColor": colors.progressColor,
            "progressOutlineColor": colors.progressOutlineColor,
            "progressFutureColor": colors.progressFutureColor,
            "previewColor": colors.previewColor,
            "previewOutlineColor": colors.previewOutlineColor,
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: options),
              let json = String(data: data, encoding: .utf8) else {
            return
        }

        webView.evaluateJavaScript("window.MapBridge.updateNavigationTrace(\(json))") { _, error in
            if let error {
                print("VisioOneBridge: updateNavigationTrace failed: \(error.localizedDescription)")
            }
        }
    }

    /// Computes a route like `computeNavigation` above, but additionally
    /// excludes one or more segment "particularities" (e.g. elevators,
    /// stairs) from consideration via `venue.computeNavigation()`'s
    /// `excludedAttributes` option (see
    /// `docs/features/navigation-exclude-modalities.md`). Added as its own
    /// bridge method rather than an `excludedAttributes` parameter on
    /// `computeNavigation` itself -- same "new method, not a signature
    /// change" idiom as `updateNavigationTrace` above.
    ///
    /// On this app's shared demo venue, the attribute string for an elevator
    /// hop is `'lift'` -- *not* `'elevator'`, despite the SDK's own JSDoc
    /// comment on `excludedAttributes` (confirmed live, see the feature doc).
    /// This method takes the raw attribute strings as-is; resolving
    /// "Avoid elevator" to `'lift'` is `NavigationExcludeModalitiesOverlay`'s
    /// job, not this bridge method's.
    ///
    /// Errors thrown by `venue.computeNavigation()` (e.g. no route survives
    /// the exclusion) are not caught JS-side, same as plain
    /// `computeNavigation` -- they propagate to this call's completion
    /// handler, same error path as an ordinary unreachable origin/destination
    /// pair.
    ///
    /// The request is JSON-encoded via `JSONSerialization` before being
    /// interpolated into the generated script, same rule as the other bridge
    /// methods above.
    func computeNavigationExcludingModalities(
        origin: String,
        destination: String,
        isAccessible: Bool,
        excludedAttributes: [String]
    ) {
        guard let webView else { return }

        let request: [String: Any] = [
            "origin": origin,
            "destination": destination,
            "isAccessible": isAccessible,
            "excludedAttributes": excludedAttributes,
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: request),
              let json = String(data: data, encoding: .utf8) else {
            return
        }

        webView.evaluateJavaScript("window.MapBridge.computeNavigationExcludingModalities(\(json))") { _, error in
            if let error {
                print("VisioOneBridge: computeNavigationExcludingModalities failed: \(error.localizedDescription)")
            }
        }
    }

    /// Clears whatever navigation trace is currently displayed (from either
    /// `computeNavigation` or `computeNavigationExcludingModalities`) via
    /// `view.removeCurrentNavigationTrace()`, so the "Clear" button on
    /// `NavigationExcludeModalitiesOverlay` has something real to act on
    /// beyond just resetting its own text fields. No-op JS-side if nothing is
    /// currently displayed -- see `map.html`. See
    /// `docs/features/navigation-exclude-modalities.md`.
    func clearNavigationTrace() {
        webView?.evaluateJavaScript("window.MapBridge.clearNavigationTrace()") { _, error in
            if let error {
                print("VisioOneBridge: clearNavigationTrace failed: \(error.localizedDescription)")
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

    /// Resolves a zone POI's boundary via `window.MapBridge.resolveZonePolygon`
    /// so the caller can run its own point-in-polygon check against a
    /// simulated tracked position -- the SDK has no geofencing/containment
    /// primitive itself (see `docs/features/geofencing.md`). Like
    /// `resolvePoiPosition`, this is a synchronous JS lookup read straight
    /// from `evaluateJavaScript`'s return value.
    func resolveZonePolygon(_ poiId: String) async -> ResolveZoneResult {
        guard let webView else { return .bridgeFailure }

        guard let data = try? JSONSerialization.data(withJSONObject: poiId, options: [.fragmentsAllowed]),
              let json = String(data: data, encoding: .utf8) else {
            return .bridgeFailure
        }

        return await withCheckedContinuation { continuation in
            webView.evaluateJavaScript("window.MapBridge.resolveZonePolygon(\(json))") { result, error in
                if let error {
                    print("VisioOneBridge: resolveZonePolygon failed: \(error.localizedDescription)")
                    continuation.resume(returning: .bridgeFailure)
                    return
                }
                guard let payload = result as? [String: Any], let status = payload["status"] as? String else {
                    continuation.resume(returning: .bridgeFailure)
                    return
                }
                switch status {
                case "notFound":
                    continuation.resume(returning: .notFound)
                case "noSurface":
                    continuation.resume(returning: .noSurface)
                case "ok":
                    guard let rawPositions = payload["positions"] as? [[String: Any]] else {
                        continuation.resume(returning: .bridgeFailure)
                        return
                    }
                    let positions = rawPositions.compactMap { entry -> GeoPosition? in
                        guard let latitude = entry["latitude"] as? Double,
                              let longitude = entry["longitude"] as? Double else { return nil }
                        return GeoPosition(latitude: latitude, longitude: longitude)
                    }
                    continuation.resume(returning: .zone(positions: positions))
                default:
                    continuation.resume(returning: .bridgeFailure)
                }
            }
        }
    }

    /// Colors/reverts a zone POI's surface(s) as the "inside the geofence"
    /// alert, via `window.MapBridge.setZoneAlert` (same `venue.updateSurface()`
    /// + `'initial'`-to-revert idiom as `highlightCategory`). Fire-and-forget,
    /// called whenever the caller's point-in-polygon check flips the
    /// inside/outside state. See `docs/features/geofencing.md`.
    func setZoneAlert(_ placeId: String, active: Bool) {
        guard let webView else { return }

        guard let data = try? JSONSerialization.data(withJSONObject: placeId, options: [.fragmentsAllowed]),
              let json = String(data: data, encoding: .utf8) else {
            return
        }

        webView.evaluateJavaScript("window.MapBridge.setZoneAlert(\(json), \(active))") { _, error in
            if let error {
                print("VisioOneBridge: setZoneAlert failed: \(error.localizedDescription)")
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

    /// Places the demo icon in the 3D scene via `venue.createImage()`, owned
    /// by the anchor POI `anchorId` and positioned at that POI's own
    /// label/marker position -- the same anchor-position lookup
    /// `createDynamicPOI` uses (`anchorPositionOf` in `map.html`). Any icon
    /// already placed is removed first, so at most one exists at a time.
    /// Called via `callAsyncJavaScript`, same idiom as `createDynamicPOI`, so
    /// an unknown POI, a position-less POI, or `createImage` throwing all
    /// come back as normal values. On success, updates `placedIconAnchorId`.
    func placeIcon(anchorId: String) async -> PlaceIconResult {
        guard let webView else { return .failure("Map not ready") }

        return await withCheckedContinuation { continuation in
            webView.callAsyncJavaScript(
                "return await window.MapBridge.placeIconImage(imageId, anchorId, url, orientationType);",
                arguments: [
                    "imageId": Self.iconImageId,
                    "anchorId": anchorId,
                    "url": Self.iconDataURL,
                    "orientationType": iconOrientation.rawValue,
                ],
                in: nil,
                in: .page
            ) { [weak self] result in
                switch result {
                case .success(let value):
                    guard let payload = value as? [String: Any], let status = payload["status"] as? String else {
                        continuation.resume(returning: .failure("Unexpected bridge response"))
                        return
                    }
                    switch status {
                    case "placed":
                        self?.placedIconAnchorId = anchorId
                        continuation.resume(returning: .placed)
                    case "poiNotFound":
                        continuation.resume(returning: .poiNotFound)
                    case "noPosition":
                        continuation.resume(returning: .noPosition)
                    default:
                        continuation.resume(returning: .failure(payload["message"] as? String ?? status))
                    }
                case .failure(let error):
                    print("VisioOneBridge: placeIconImage failed: \(error.localizedDescription)")
                    continuation.resume(returning: .failure(error.localizedDescription))
                }
            }
        }
    }

    /// Selects the icon's orientation and, if an icon is placed, applies it
    /// live via `venue.updateImage(image, { orientationType })` --
    /// fire-and-forget, same idiom as `updateDynamicLabelText`.
    func setIconOrientation(_ orientation: IconOrientation) {
        iconOrientation = orientation
        guard let webView, placedIconAnchorId != nil else { return }

        webView.callAsyncJavaScript(
            "window.MapBridge.updateIconImageOrientation(imageId, orientationType);",
            arguments: ["imageId": Self.iconImageId, "orientationType": orientation.rawValue],
            in: nil,
            in: .page
        ) { result in
            if case .failure(let error) = result {
                print("VisioOneBridge: updateIconImageOrientation failed: \(error.localizedDescription)")
            }
        }
    }

    /// Removes the placed icon via `venue.removeImage()`; the anchor POI
    /// itself is untouched. Clears `placedIconAnchorId` optimistically. No-op
    /// if nothing is placed.
    func removeIcon() {
        guard let webView, placedIconAnchorId != nil else { return }

        placedIconAnchorId = nil
        webView.callAsyncJavaScript(
            "window.MapBridge.removeIconImage(imageId);",
            arguments: ["imageId": Self.iconImageId],
            in: nil,
            in: .page
        ) { result in
            if case .failure(let error) = result {
                print("VisioOneBridge: removeIconImage failed: \(error.localizedDescription)")
            }
        }
    }

    /// Places free text on the map via `venue.createLabel()`, owned by the
    /// anchor POI `anchorId` and positioned ~4 m off that POI's own
    /// label/marker position -- the same anchor-position lookup
    /// `createDynamicPOI`/`placeIcon` use (`anchorPositionOf` in
    /// `map.html`) -- with the currently selected color/size/rotation. The
    /// JS side validates everything (text, anchor POI, anchor position)
    /// before touching an already placed label: a failed validation leaves
    /// it in place and still usable; only once all checks pass is it
    /// replaced, so at most one exists. Called via `callAsyncJavaScript`, same idiom as `placeIcon`, so every
    /// outcome comes back as a normal value. See
    /// `docs/features/custom-text-label.md`.
    @MainActor
    func placeTextLabel(anchorId: String, text: String) async -> TextLabelResult {
        guard let webView else { return .failure("Map not ready") }

        let result = await callTextLabelBridge(
            "return await window.MapBridge.placeTextLabel(anchorId, text, color, width, height, rotation);",
            arguments: [
                "anchorId": anchorId,
                "text": text,
                "color": textLabelColor.rawValue,
                "width": textLabelSize.width,
                "height": textLabelSize.height,
                "rotation": textLabelRotation,
            ],
            in: webView
        )
        switch result {
        case .success:
            placedTextLabelAnchorId = anchorId
            placedTextLabelText = text
        case .failure:
            // Validation passed and the previous label was already removed,
            // but venue.createLabel itself threw: nothing is placed anymore.
            placedTextLabelAnchorId = nil
            placedTextLabelText = nil
        case .textRequired, .poiNotFound, .noPosition, .noLabel:
            // Validation failed before anything was touched: the existing
            // label (if any) is still placed and usable.
            break
        }
        return result
    }

    /// Changes the placed label's text via `venue.updateLabel(label, { text })`.
    @MainActor
    func updateTextLabelText(_ text: String) async -> TextLabelResult {
        guard let webView else { return .failure("Map not ready") }
        guard placedTextLabelAnchorId != nil else { return .noLabel }

        let result = await callTextLabelBridge(
            "return window.MapBridge.updateTextLabel({ text: text });",
            arguments: ["text": text],
            in: webView
        )
        if result == .success {
            placedTextLabelText = text
        }
        return result
    }

    /// Selects the label color and, if a label is placed, applies it live
    /// via `venue.updateLabel(label, { color })`.
    @MainActor
    func setTextLabelColor(_ color: TextLabelColor) {
        textLabelColor = color
        guard let webView, placedTextLabelAnchorId != nil else { return }
        Task { @MainActor in
            _ = await callTextLabelBridge(
                "return window.MapBridge.updateTextLabel({ color: color });",
                arguments: ["color": color.rawValue],
                in: webView
            )
        }
    }

    /// Selects the label size and, if a label is placed, applies it live via
    /// `venue.updateLabel(label, { width, height })` -- always both, since
    /// `width` alone also resets `height` to `width`.
    @MainActor
    func setTextLabelSize(_ size: TextLabelSize) {
        textLabelSize = size
        guard let webView, placedTextLabelAnchorId != nil else { return }
        Task { @MainActor in
            _ = await callTextLabelBridge(
                "return window.MapBridge.updateTextLabel({ width: width, height: height });",
                arguments: ["width": size.width, "height": size.height],
                in: webView
            )
        }
    }

    /// Selects the label rotation (degrees) and, if a label is placed,
    /// recreates it with the new rotation: `rotation` is only accepted by
    /// `venue.createLabel`, not by `venue.updateLabel`.
    @MainActor
    func setTextLabelRotation(_ rotation: Int) {
        textLabelRotation = rotation
        guard let webView, placedTextLabelAnchorId != nil else { return }
        Task { @MainActor in
            let result = await callTextLabelBridge(
                "return window.MapBridge.setTextLabelRotation(rotation);",
                arguments: ["rotation": rotation],
                in: webView
            )
            if result != .success {
                placedTextLabelAnchorId = nil
                placedTextLabelText = nil
            }
        }
    }

    /// Removes the placed label via `venue.removeLabel()`; the anchor POI
    /// and its own map label are untouched. Clears the placed state
    /// optimistically. No-op if nothing is placed.
    @MainActor
    func removeTextLabel() {
        guard let webView, placedTextLabelAnchorId != nil else { return }

        placedTextLabelAnchorId = nil
        placedTextLabelText = nil
        webView.callAsyncJavaScript(
            "window.MapBridge.removeTextLabel();",
            arguments: [:],
            in: nil,
            in: .page
        ) { result in
            if case .failure(let error) = result {
                print("VisioOneBridge: removeTextLabel failed: \(error.localizedDescription)")
            }
        }
    }

    /// Runs one of the text-label bridge functions and maps its
    /// `{ status, message? }` result into a `TextLabelResult`.
    @MainActor
    private func callTextLabelBridge(_ script: String, arguments: [String: Any], in webView: WKWebView) async -> TextLabelResult {
        await withCheckedContinuation { continuation in
            webView.callAsyncJavaScript(script, arguments: arguments, in: nil, in: .page) { result in
                switch result {
                case .success(let value):
                    guard let payload = value as? [String: Any], let status = payload["status"] as? String else {
                        continuation.resume(returning: .failure("Unexpected bridge response"))
                        return
                    }
                    switch status {
                    case "placed", "updated":
                        continuation.resume(returning: .success)
                    case "textRequired":
                        continuation.resume(returning: .textRequired)
                    case "poiNotFound":
                        continuation.resume(returning: .poiNotFound)
                    case "noPosition":
                        continuation.resume(returning: .noPosition)
                    case "noLabel":
                        continuation.resume(returning: .noLabel)
                    default:
                        continuation.resume(returning: .failure(payload["message"] as? String ?? status))
                    }
                case .failure(let error):
                    print("VisioOneBridge: text label call failed: \(error.localizedDescription)")
                    continuation.resume(returning: .failure(error.localizedDescription))
                }
            }
        }
    }

    /// Pins an interactive HTML badge on the map via
    /// `venue.createMarker({ poi, position, element })`, owned by the anchor
    /// POI `anchorId` and positioned ~4 m off that POI's own label/marker
    /// position -- the same anchor-position lookup as `placeTextLabel`
    /// (`anchorPositionOf` in `map.html`). The badge element itself is
    /// created by the JS side; its taps come back as `htmlBadgeTapped`
    /// messages (see `userContentController`). The JS side validates
    /// everything (text, anchor POI, anchor position) before touching an
    /// already placed badge, so a failed place leaves it untouched. On
    /// success the badge starts visible and the tap counter resets to 0.
    /// See `docs/features/html-overlay-marker.md`.
    @MainActor
    func placeHtmlBadge(anchorId: String, text: String) async -> HtmlBadgeResult {
        guard let webView else { return .failure("Map not ready") }

        let result = await callHtmlBadgeBridge(
            "return await window.MapBridge.placeHtmlBadge(anchorId, text);",
            arguments: ["anchorId": anchorId, "text": text],
            in: webView
        )
        switch result {
        case .success:
            placedHtmlBadgeAnchorId = anchorId
            placedHtmlBadgeText = text
            isHtmlBadgeVisible = true
            htmlBadgeTapCount = 0
        case .failure:
            // Validation passed and the previous badge was already removed,
            // but venue.createMarker itself threw: nothing is placed anymore.
            placedHtmlBadgeAnchorId = nil
            placedHtmlBadgeText = nil
            isHtmlBadgeVisible = true
        case .textRequired, .poiNotFound, .noPosition, .noBadge:
            // Validation failed before anything was touched.
            break
        }
        return result
    }

    /// Changes the badge text -- a plain DOM edit on the marker's element on
    /// the JS side, no SDK call.
    @MainActor
    func updateHtmlBadgeText(_ text: String) async -> HtmlBadgeResult {
        guard let webView else { return .failure("Map not ready") }
        guard placedHtmlBadgeAnchorId != nil else { return .noBadge }

        let result = await callHtmlBadgeBridge(
            "return window.MapBridge.updateHtmlBadgeText(text);",
            arguments: ["text": text],
            in: webView
        )
        if result == .success {
            placedHtmlBadgeText = text
        }
        return result
    }

    /// Shows/hides the placed badge via
    /// `venue.updateMarker(marker, { isVisible })`.
    @MainActor
    func setHtmlBadgeVisible(_ isVisible: Bool) async {
        guard let webView, placedHtmlBadgeAnchorId != nil else { return }

        let result = await callHtmlBadgeBridge(
            "return window.MapBridge.setHtmlBadgeVisible(isVisible);",
            arguments: ["isVisible": isVisible],
            in: webView
        )
        if result == .success {
            isHtmlBadgeVisible = isVisible
        }
    }

    /// Removes the badge via `venue.removeMarker()` (which also detaches its
    /// element from the DOM); the anchor POI is untouched. Clears the placed
    /// state optimistically. No-op if nothing is placed.
    @MainActor
    func removeHtmlBadge() {
        guard let webView, placedHtmlBadgeAnchorId != nil else { return }

        placedHtmlBadgeAnchorId = nil
        placedHtmlBadgeText = nil
        isHtmlBadgeVisible = true
        webView.callAsyncJavaScript(
            "window.MapBridge.removeHtmlBadge();",
            arguments: [:],
            in: nil,
            in: .page
        ) { result in
            if case .failure(let error) = result {
                print("VisioOneBridge: removeHtmlBadge failed: \(error.localizedDescription)")
            }
        }
    }

    /// Runs one of the HTML-badge bridge functions and maps its
    /// `{ status, message? }` result into an `HtmlBadgeResult`.
    @MainActor
    private func callHtmlBadgeBridge(_ script: String, arguments: [String: Any], in webView: WKWebView) async -> HtmlBadgeResult {
        await withCheckedContinuation { continuation in
            webView.callAsyncJavaScript(script, arguments: arguments, in: nil, in: .page) { result in
                switch result {
                case .success(let value):
                    guard let payload = value as? [String: Any], let status = payload["status"] as? String else {
                        continuation.resume(returning: .failure("Unexpected bridge response"))
                        return
                    }
                    switch status {
                    case "placed", "updated":
                        continuation.resume(returning: .success)
                    case "textRequired":
                        continuation.resume(returning: .textRequired)
                    case "poiNotFound":
                        continuation.resume(returning: .poiNotFound)
                    case "noPosition":
                        continuation.resume(returning: .noPosition)
                    case "noBadge":
                        continuation.resume(returning: .noBadge)
                    default:
                        continuation.resume(returning: .failure(payload["message"] as? String ?? status))
                    }
                case .failure(let error):
                    print("VisioOneBridge: HTML badge call failed: \(error.localizedDescription)")
                    continuation.resume(returning: .failure(error.localizedDescription))
                }
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

    /// Reads `view.themes` via `window.MapBridge.getThemes` into `themes`.
    /// A synchronous read of data the SDK already holds, so a plain
    /// `evaluateJavaScript`, same idiom as `getCategories`. See
    /// `docs/features/custom-theme.md`.
    @MainActor
    func loadThemes() async {
        guard let webView else { return }
        let result: [String]? = await withCheckedContinuation { continuation in
            webView.evaluateJavaScript("window.MapBridge.getThemes()") { result, error in
                if let error {
                    print("VisioOneBridge: getThemes failed: \(error.localizedDescription)")
                }
                continuation.resume(returning: result as? [String])
            }
        }
        if let result {
            themes = result
        }
    }

    /// Switches the 3D scene lighting via `view.setTheme(name)`. Updates
    /// `currentTheme` optimistically and rolls it back if the SDK throws
    /// (an id not in `view.themes`). See `docs/features/custom-theme.md`.
    @MainActor
    func setTheme(_ name: String) {
        guard let webView else { return }
        let previous = currentTheme
        currentTheme = name
        webView.callAsyncJavaScript(
            "return window.MapBridge.setTheme(name);",
            arguments: ["name": name],
            in: nil,
            in: .page
        ) { [weak self] result in
            if Self.bridgeError(result) != nil {
                self?.currentTheme = previous
            }
        }
    }

    /// Recolors the SDK's UI buttons' background via `view.accentColor`.
    @MainActor
    func setThemeAccentColor(_ color: ThemeAccentColor) {
        themeAccentColor = color
        applyAccentColors(accent: color.rawValue, text: nil)
    }

    /// Recolors the SDK's UI buttons' text via `view.textAccentColor`.
    @MainActor
    func setThemeTextAccentColor(_ color: ThemeTextAccentColor) {
        themeTextAccentColor = color
        applyAccentColors(accent: nil, text: color.rawValue)
    }

    /// Back to the SDK defaults: theme `"day"`, accent `#0094F0`, text
    /// accent `#FFFFFF`.
    @MainActor
    func resetTheme() {
        setTheme(Self.defaultTheme)
        themeAccentColor = .blue
        themeTextAccentColor = .white
        applyAccentColors(accent: ThemeAccentColor.blue.rawValue, text: ThemeTextAccentColor.white.rawValue)
    }

    @MainActor
    private func applyAccentColors(accent: String?, text: String?) {
        guard let webView else { return }
        webView.callAsyncJavaScript(
            "return window.MapBridge.setAccentColors(accent, text);",
            arguments: ["accent": accent ?? NSNull(), "text": text ?? NSNull()],
            in: nil,
            in: .page
        ) { result in
            _ = Self.bridgeError(result)
        }
    }

    /// Returns (and logs) the error of a `{ status, message? }` bridge call,
    /// `nil` when it succeeded.
    private static func bridgeError(_ result: Result<Any, Error>) -> String? {
        switch result {
        case .success(let value):
            guard let payload = value as? [String: Any], payload["status"] as? String == "applied" else {
                let message = (value as? [String: Any])?["message"] as? String ?? "Unexpected bridge response"
                print("VisioOneBridge: custom theme call failed: \(message)")
                return message
            }
            return nil
        case .failure(let error):
            print("VisioOneBridge: custom theme call failed: \(error.localizedDescription)")
            return error.localizedDescription
        }
    }

    /// Resets to `.loading` and reloads the page, rather than leaving the UI
    /// stuck on `.error` until the next JS message arrives.
    func reload() {
        loadState = .loading
        webView?.reload()
    }

    /// Re-loads the venue against a caller-supplied `baseURL` -- unlike every
    /// other bridge method, `baseURL` is a `loadVenue` option, not a property
    /// on an already-loaded venue/view, so this can't just call into the
    /// existing page; it has to redo the whole page load. When `newBaseURL`
    /// differs from the current one, updating `baseURL` changes
    /// `FeatureMapView`'s `.id(bridge.baseURL)` on `MapWebView`, which makes
    /// SwiftUI tear down and recreate the underlying `WKWebView` from
    /// scratch (a fresh `loadFileURL` call with the new `?baseURL=` query
    /// item, see `MapWebView.swift`) -- otherwise (retrying the exact same
    /// value) the `.id()` wouldn't change, so this falls back to a plain
    /// `webView.reload()` instead. Either way `loadState` resets to
    /// `.loading` first so the UI doesn't sit on a stale `.ready`/`.error`
    /// while the new load is in flight. See `docs/features/custom-base-url.md`.
    func reloadWithBaseURL(_ newBaseURL: String) {
        loadState = .loading
        if newBaseURL == baseURL {
            webView?.reload()
        } else {
            baseURL = newBaseURL
        }
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
        case "htmlBadgeTapped":
            // Sent by the badge element's own click listener in map.html
            // (see docs/features/html-overlay-marker.md).
            htmlBadgeTapCount += 1
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
