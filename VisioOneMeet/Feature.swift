import Foundation

enum Feature: String, CaseIterable, Identifiable, Hashable {
    case resetView
    case occupancySimulated
    case poiClick
    case goToPoi
    case floorSelector
    case computeNavigation
    case uiPartVisibility
    case nativeUiReplacement
    case simulatedPosition
    case cameraLockOnPosition
    case clickableSurface
    case customData
    case categoryHighlight
    case dynamicPoiCrud
    case runtimeLocale

    var id: String { slug }

    /// Map hash to load instead of `map.html`'s hardcoded default, or `nil`
    /// to keep that default. Only `.customData` overrides it today: the
    /// shared demo map has no CustomData published, so that feature alone
    /// points at a dedicated map known to have some (see
    /// `docs/features/custom-data.md`). Every other feature stays `nil` and
    /// is completely unaffected.
    var mapHashOverride: String? {
        switch self {
        case .customData:
            return "kd9426d8cb3f1c532f22b5bcbd325c280bd351feb"
        default:
            return nil
        }
    }

    var slug: String {
        switch self {
        case .resetView:
            return "reset-view"
        case .occupancySimulated:
            return "occupancy-simulated"
        case .poiClick:
            return "poi-click"
        case .goToPoi:
            return "goto-poi"
        case .floorSelector:
            return "floor-selector"
        case .computeNavigation:
            return "compute-navigation"
        case .uiPartVisibility:
            return "ui-part-visibility"
        case .nativeUiReplacement:
            return "native-ui-replacement"
        case .simulatedPosition:
            return "simulated-position"
        case .cameraLockOnPosition:
            return "camera-lock-on-position"
        case .clickableSurface:
            return "clickable-surface"
        case .customData:
            return "custom-data"
        case .categoryHighlight:
            return "category-highlight"
        case .dynamicPoiCrud:
            return "dynamic-poi-crud"
        case .runtimeLocale:
            return "runtime-locale"
        }
    }

    var title: LocalizedStringResource {
        switch self {
        case .resetView:
            return "feature.reset_view.title"
        case .occupancySimulated:
            return "feature.occupancy_simulated.title"
        case .poiClick:
            return "feature.poi_click.title"
        case .goToPoi:
            return "feature.goto_poi.title"
        case .floorSelector:
            return "feature.floor_selector.title"
        case .computeNavigation:
            return "feature.compute_navigation.title"
        case .uiPartVisibility:
            return "feature.ui_part_visibility.title"
        case .nativeUiReplacement:
            return "feature.native_ui_replacement.title"
        case .simulatedPosition:
            return "feature.simulated_position.title"
        case .cameraLockOnPosition:
            return "feature.camera_lock_on_position.title"
        case .clickableSurface:
            return "feature.clickable_surface.title"
        case .customData:
            return "feature.custom_data.title"
        case .categoryHighlight:
            return "feature.category_highlight.title"
        case .dynamicPoiCrud:
            return "feature.dynamic_poi_crud.title"
        case .runtimeLocale:
            return "feature.runtime_locale.title"
        }
    }

    var description: LocalizedStringResource {
        switch self {
        case .resetView:
            return "feature.reset_view.description"
        case .occupancySimulated:
            return "feature.occupancy_simulated.description"
        case .poiClick:
            return "feature.poi_click.description"
        case .goToPoi:
            return "feature.goto_poi.description"
        case .floorSelector:
            return "feature.floor_selector.description"
        case .computeNavigation:
            return "feature.compute_navigation.description"
        case .uiPartVisibility:
            return "feature.ui_part_visibility.description"
        case .nativeUiReplacement:
            return "feature.native_ui_replacement.description"
        case .simulatedPosition:
            return "feature.simulated_position.description"
        case .cameraLockOnPosition:
            return "feature.camera_lock_on_position.description"
        case .clickableSurface:
            return "feature.clickable_surface.description"
        case .customData:
            return "feature.custom_data.description"
        case .categoryHighlight:
            return "feature.category_highlight.description"
        case .dynamicPoiCrud:
            return "feature.dynamic_poi_crud.description"
        case .runtimeLocale:
            return "feature.runtime_locale.description"
        }
    }
}
