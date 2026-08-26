import Foundation

enum Feature: String, CaseIterable, Identifiable, Hashable {
    case resetView
    case occupancySimulated
    case poiClick
    case goToPoi
    case floorSelector
    case computeNavigation
    case uiPartVisibility
    case simulatedPosition
    case cameraLockOnPosition
    case clickableSurface
    case customData

    var id: String { slug }

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
        case .simulatedPosition:
            return "simulated-position"
        case .cameraLockOnPosition:
            return "camera-lock-on-position"
        case .clickableSurface:
            return "clickable-surface"
        case .customData:
            return "custom-data"
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
        case .simulatedPosition:
            return "feature.simulated_position.title"
        case .cameraLockOnPosition:
            return "feature.camera_lock_on_position.title"
        case .clickableSurface:
            return "feature.clickable_surface.title"
        case .customData:
            return "feature.custom_data.title"
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
        case .simulatedPosition:
            return "feature.simulated_position.description"
        case .cameraLockOnPosition:
            return "feature.camera_lock_on_position.description"
        case .clickableSurface:
            return "feature.clickable_surface.description"
        case .customData:
            return "feature.custom_data.description"
        }
    }
}
