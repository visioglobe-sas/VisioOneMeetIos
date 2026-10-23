import Foundation

// Values of Visioglobe's shared demo map: replace them with your own map's hash and POI ids.
enum DemoMap {
    /// Hash of the shared demo map loaded by every feature screen (passed to
    /// `map.html` as `?vg_maphash=`, see `MapWebView`).
    static let mapHash = "kbae8e6c066cca4b02c2afac2bc963a643d87437a"
    /// Dedicated map for the custom-data screen only: the shared demo map has
    /// no CustomData published. See docs/features/custom-data.md.
    static let customDataMapHash = "kd9426d8cb3f1c532f22b5bcbd325c280bd351feb"

    /// goto-poi: a shop with a surface.
    static let gotoPoiId = "B3-UL00-ID0076"
    /// occupancy-simulated: a POI with a surface to color.
    static let occupancyPlaceId = "B3-UL00-ID0065"
    /// clickable-surface: a POI with a surface.
    static let clickableSurfacePlaceId = "B3-UL00-ID0064"

    /// compute-navigation and custom-navigation-trace.
    static let itineraryFrom = "B4-UL00-ID0009"
    static let itineraryTo = "B3-UL00-ID0064"
    /// navigation-exclude-modalities: the default route takes an elevator
    /// ('lift') hop, excluding it reroutes through stairways.
    static let excludeModalitiesFrom = "B1-LL01-ID0013"
    static let excludeModalitiesTo = "B1-UL02-ID0012"
    /// accessible-mode: the fastest route takes stairs, `isAccessible`
    /// reroutes through an elevator.
    static let accessibleFrom = "B4-UL00-ID0010"
    static let accessibleTo = "B4-UL01-ID0014"

    /// simulated-position, camera-lock-on-position, geofencing and
    /// accuracy-circle-style: origin and destination of the simulated walk
    /// (both need a label, marker or image to read a position from).
    static let trackingFrom = "B4-UL00-ID0009"
    static let trackingTo = "B4-UL00-ID0010"
    /// geofencing: a POI with a surface, used as the zone.
    static let geofenceZoneId = "B4-UL00-ID0010"

    /// custom-data (on `customDataMapHash`): POIs carrying real CustomData,
    /// the first one prefills the field, all are offered as quick-select chips.
    static let customDataPlaceId = "B3-UL00-ID0065"
    static let customDataPlaceIds = ["B1", "B3-UL00-ID0065", "B3-UL00-ID0064"]

    /// dynamic-poi-crud: id of the POI to create.
    static let newPoiId = "demo-poi"
    /// "Restaurant", ground floor of building B4: has a label to read a
    /// position from (a surface-only POI such as `B3-UL00-ID0065` has none).
    /// Anchor of dynamic-poi-crud, 3d-icon-marker, custom-text-label and
    /// html-overlay-marker.
    static let anchorPoiId = "B4-UL00-ID0009"

    /// Default texts, localized EN/FR in Localizable.xcstrings.
    static var dynamicPoiLabelText: String { String(localized: "demo.dynamic_poi.label_text") }
    static var textLabelText: String { String(localized: "demo.text_label.text") }
    static var htmlBadgeText: String { String(localized: "demo.html_badge.text") }

    /// camera-showcase-carousel: the tour's stops, in order (sent to
    /// `map.html` on start).
    static let carouselStopIds = ["B4-UL00-ID0009", "B1-LL01-ID0152", "B3-UL00-ID0064", "B4-UL03-ID0015"]
}
