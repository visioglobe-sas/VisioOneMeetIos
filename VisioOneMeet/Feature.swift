import Foundation

enum Feature: String, CaseIterable, Identifiable, Hashable {
    case resetView
    case occupancySimulated

    var id: String { slug }

    var slug: String {
        switch self {
        case .resetView:
            return "reset-view"
        case .occupancySimulated:
            return "occupancy-simulated"
        }
    }

    var title: LocalizedStringResource {
        switch self {
        case .resetView:
            return "feature.reset_view.title"
        case .occupancySimulated:
            return "feature.occupancy_simulated.title"
        }
    }

    var description: LocalizedStringResource {
        switch self {
        case .resetView:
            return "feature.reset_view.description"
        case .occupancySimulated:
            return "feature.occupancy_simulated.description"
        }
    }
}
