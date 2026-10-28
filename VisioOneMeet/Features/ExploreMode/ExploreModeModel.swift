import SwiftUI

/// The SDK's 3 building-exploration modes, mirrored from `view.currentExploreMode`.
/// Raw values match the JS SDK's `ExploreMode` type exactly (case-sensitive). See
/// `docs/features/explore-mode.md`.
enum MapExploreMode: String, Equatable {
    case global
    case building
    case floor
}

@MainActor
final class ExploreModeModel: ObservableObject, FeatureModel {
    /// The venue's current building-exploration mode, pushed by the JS side
    /// once on `ready` and again on every SDK `exploremodechanged` event --
    /// including changes triggered by direct camera/map interaction, not
    /// just `setExploreMode` calls from this app (e.g. a click while in
    /// `.building` mode auto-switches the SDK to `.floor`). Defaults to
    /// `.global` (the SDK's own resting state) until the first push arrives.
    @Published private(set) var currentExploreMode: MapExploreMode = .global

    let bridge: VisioOneBridge

    init(bridge: VisioOneBridge) {
        self.bridge = bridge
        bridge.onMessage("exploreModeChanged") { [weak self] payload in
            guard let payload = payload as? [String: Any],
                  let rawMode = payload["currentExploreMode"] as? String,
                  let mode = MapExploreMode(rawValue: rawMode) else { return }
            self?.currentExploreMode = mode
        }
        bridge.onReload { [weak self] in self?.currentExploreMode = .global }
    }

    func makePanel() -> AnyView { AnyView(ExploreModePanel(model: self)) }
}
