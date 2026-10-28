import SwiftUI

/// One entry of the feature menu: everything the menu (`ContentView`) and
/// the screen (`FeatureScreen`) need to know about a feature, in one table
/// (`Feature.all`). The feature's own code lives in
/// `Features/<Feature>/` (panel, model, bridge calls) and
/// `WebContent/features/<slug>.js` (SDK calls); its doc in
/// `docs/features/<slug>.md`.
struct Feature: Identifiable, Hashable {
    enum Content {
        /// A map screen: map + FAB + control panel, driven by the model
        /// this closure creates for the screen's bridge.
        case map(@MainActor (VisioOneBridge) -> FeatureModel)
        /// A screen of the feature's own, with no map.
        case screen(@MainActor (Feature) -> AnyView)
    }

    /// Kebab-case id, identical to `docs/features/<slug>.md` and
    /// `WebContent/features/<slug>.js`.
    let slug: String
    /// Menu title and description, localized in `Localizable.xcstrings`.
    let title: LocalizedStringResource
    let description: LocalizedStringResource
    /// The map this screen loads and how (see `MapPageOptions`): the shared
    /// demo map with the SDK defaults, unless the feature needs otherwise.
    var pageOptions = MapPageOptions(mapHash: DemoMap.mapHash)
    let content: Content

    var id: String { slug }

    static func == (lhs: Feature, rhs: Feature) -> Bool { lhs.slug == rhs.slug }
    func hash(into hasher: inout Hasher) { hasher.combine(slug) }
}

extension Feature {
    /// The menu, in display order.
    static let all: [Feature] = [
        Feature(
            slug: "reset-view",
            title: "feature.reset_view.title",
            description: "feature.reset_view.description",
            content: .map { ResetViewModel(bridge: $0) }
        ),
        Feature(
            slug: "occupancy-simulated",
            title: "feature.occupancy_simulated.title",
            description: "feature.occupancy_simulated.description",
            content: .map { OccupancySimulatedModel(bridge: $0) }
        ),
        Feature(
            slug: "poi-click",
            title: "feature.poi_click.title",
            description: "feature.poi_click.description",
            content: .map { PoiClickModel(bridge: $0) }
        ),
        Feature(
            slug: "goto-poi",
            title: "feature.goto_poi.title",
            description: "feature.goto_poi.description",
            content: .map { GotoPoiModel(bridge: $0) }
        ),
        Feature(
            slug: "floor-selector",
            title: "feature.floor_selector.title",
            description: "feature.floor_selector.description",
            content: .map { FloorSelectorModel(bridge: $0) }
        ),
        Feature(
            slug: "explore-mode",
            title: "feature.explore_mode.title",
            description: "feature.explore_mode.description",
            content: .map { ExploreModeModel(bridge: $0) }
        ),
        Feature(
            slug: "compute-navigation",
            title: "feature.compute_navigation.title",
            description: "feature.compute_navigation.description",
            content: .map { ComputeNavigationModel(bridge: $0) }
        ),
        Feature(
            slug: "ui-part-visibility",
            title: "feature.ui_part_visibility.title",
            description: "feature.ui_part_visibility.description",
            content: .map { UiPartVisibilityModel(bridge: $0) }
        ),
        Feature(
            slug: "native-ui-replacement",
            title: "feature.native_ui_replacement.title",
            description: "feature.native_ui_replacement.description",
            content: .map { NativeUiReplacementModel(bridge: $0) }
        ),
        Feature(
            slug: "simulated-position",
            title: "feature.simulated_position.title",
            description: "feature.simulated_position.description",
            content: .map { SimulatedPositionModel(bridge: $0) }
        ),
        Feature(
            slug: "camera-lock-on-position",
            title: "feature.camera_lock_on_position.title",
            description: "feature.camera_lock_on_position.description",
            content: .map { CameraLockOnPositionModel(bridge: $0) }
        ),
        Feature(
            slug: "clickable-surface",
            title: "feature.clickable_surface.title",
            description: "feature.clickable_surface.description",
            content: .map { ClickableSurfaceModel(bridge: $0) }
        ),
        Feature(
            slug: "custom-data",
            title: "feature.custom_data.title",
            description: "feature.custom_data.description",
            // The shared demo map has no CustomData published: this screen
            // alone loads a dedicated map known to have some (see
            // docs/features/custom-data.md).
            pageOptions: MapPageOptions(mapHash: DemoMap.customDataMapHash),
            content: .map { CustomDataModel(bridge: $0) }
        ),
        Feature(
            slug: "category-highlight",
            title: "feature.category_highlight.title",
            description: "feature.category_highlight.description",
            content: .map { CategoryHighlightModel(bridge: $0) }
        ),
        Feature(
            slug: "dynamic-poi-crud",
            title: "feature.dynamic_poi_crud.title",
            description: "feature.dynamic_poi_crud.description",
            content: .map { DynamicPoiCrudModel(bridge: $0) }
        ),
        Feature(
            slug: "runtime-locale",
            title: "feature.runtime_locale.title",
            description: "feature.runtime_locale.description",
            content: .map { RuntimeLocaleModel(bridge: $0) }
        ),
        Feature(
            slug: "add-locale",
            title: "feature.add_locale.title",
            description: "feature.add_locale.description",
            content: .map { AddLocaleModel(bridge: $0) }
        ),
        Feature(
            slug: "geofencing",
            title: "feature.geofencing.title",
            description: "feature.geofencing.description",
            content: .map { GeofencingModel(bridge: $0) }
        ),
        Feature(
            slug: "custom-base-url",
            title: "feature.custom_base_url.title",
            description: "feature.custom_base_url.description",
            // Passed explicitly (the SDK's own default value) so the panel
            // can show and change it.
            pageOptions: MapPageOptions(mapHash: DemoMap.mapHash, baseURL: CustomBaseUrlModel.sdkDefaultBaseURL),
            content: .map { CustomBaseUrlModel(bridge: $0) }
        ),
        Feature(
            slug: "custom-navigation-trace",
            title: "feature.custom_navigation_trace.title",
            description: "feature.custom_navigation_trace.description",
            content: .map { CustomNavigationTraceModel(bridge: $0) }
        ),
        Feature(
            slug: "navigation-exclude-modalities",
            title: "feature.navigation_exclude_modalities.title",
            description: "feature.navigation_exclude_modalities.description",
            content: .map { NavigationExcludeModalitiesModel(bridge: $0) }
        ),
        Feature(
            slug: "accessible-mode",
            title: "feature.accessible_mode.title",
            description: "feature.accessible_mode.description",
            content: .map { AccessibleModeModel(bridge: $0) }
        ),
        Feature(
            slug: "3d-icon-marker",
            title: "feature.3d_icon_marker.title",
            description: "feature.3d_icon_marker.description",
            content: .map { IconMarker3DModel(bridge: $0) }
        ),
        Feature(
            slug: "custom-text-label",
            title: "feature.custom_text_label.title",
            description: "feature.custom_text_label.description",
            content: .map { CustomTextLabelModel(bridge: $0) }
        ),
        Feature(
            slug: "html-overlay-marker",
            title: "feature.html_overlay_marker.title",
            description: "feature.html_overlay_marker.description",
            content: .map { HtmlOverlayMarkerModel(bridge: $0) }
        ),
        Feature(
            slug: "custom-theme",
            title: "feature.custom_theme.title",
            description: "feature.custom_theme.description",
            // view.setTheme() only changes the scene lights, which aren't
            // rendered otherwise (see docs/features/custom-theme.md). Every
            // other feature keeps the SDK default, shadows being
            // computationally expensive.
            pageOptions: MapPageOptions(mapHash: DemoMap.mapHash, enableShadows: true),
            content: .map { CustomThemeModel(bridge: $0) }
        ),
        Feature(
            slug: "accuracy-circle-style",
            title: "feature.accuracy_circle_style.title",
            description: "feature.accuracy_circle_style.description",
            content: .map { AccuracyCircleStyleModel(bridge: $0) }
        ),
        Feature(
            slug: "camera-projection-toggle",
            title: "feature.camera_projection.title",
            description: "feature.camera_projection.description",
            pageOptions: MapPageOptions(mapHash: DemoMap.mapHash, cameraProjection: .perspective),
            content: .map { CameraProjectionToggleModel(bridge: $0) }
        ),
        Feature(
            slug: "camera-showcase-carousel",
            title: "feature.camera_showcase_carousel.title",
            description: "feature.camera_showcase_carousel.description",
            content: .map { CameraShowcaseCarouselModel(bridge: $0) }
        ),
        Feature(
            slug: "auth-token",
            title: "feature.auth_token.title",
            description: "feature.auth_token.description",
            // Code sample only: no map is loaded on this screen.
            content: .screen { AnyView(AuthTokenScreen(feature: $0)) }
        ),
    ]
}
