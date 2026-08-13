import Foundation

enum Feature: String, CaseIterable, Identifiable, Hashable {
    case resetView
    case occupancySimulated
    case poiClick

    var id: String { slug }

    var slug: String {
        switch self {
        case .resetView:
            return "reset-view"
        case .occupancySimulated:
            return "occupancy-simulated"
        case .poiClick:
            return "poi-click"
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
        }
    }
}
