import SwiftUI

/// The SDK's 5 default UI parts that `view.setUIPartVisible()` can
/// individually show/hide. Raw values match the JS SDK's `UIPart` type
/// exactly (case-sensitive) -- see docs/features/ui-part-visibility.md.
enum MapUIPart: String, CaseIterable, Identifiable {
    case floorSelector
    case navigation
    case poiDetails
    case search
    case userTracking

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .floorSelector:
            return "feature.ui_part_visibility.part.floor_selector"
        case .navigation:
            return "feature.ui_part_visibility.part.navigation"
        case .poiDetails:
            return "feature.ui_part_visibility.part.poi_details"
        case .search:
            return "feature.ui_part_visibility.part.search"
        case .userTracking:
            return "feature.ui_part_visibility.part.user_tracking"
        }
    }
}

/// The SDK UI parts currently hidden via `setUIPartVisible` (empty = the SDK
/// default, everything shown). The SDK has no getter for this, so it is
/// tracked here, for both ui-part-visibility's 5 switches and
/// native-ui-replacement's toggle: they show the map's real state whenever
/// the panel is reopened.
@MainActor
final class UiPartVisibilityModel: ObservableObject, FeatureModel {
    @Published private(set) var hiddenUIParts: Set<MapUIPart> = []

    let bridge: VisioOneBridge

    init(bridge: VisioOneBridge) {
        self.bridge = bridge
        bridge.onReload { [weak self] in self?.hiddenUIParts = [] }
    }

    func makePanel() -> AnyView { AnyView(UiPartVisibilityPanel(model: self)) }

    func isVisible(_ part: MapUIPart) -> Bool { !hiddenUIParts.contains(part) }

    func setVisible(_ part: MapUIPart, _ isVisible: Bool) {
        guard bridge.webView != nil else { return }
        if isVisible {
            hiddenUIParts.remove(part)
        } else {
            hiddenUIParts.insert(part)
        }
        bridge.setUIPartVisible(part, isVisible: isVisible)
    }
}
