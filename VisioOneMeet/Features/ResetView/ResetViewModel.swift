import SwiftUI

/// reset-view has no state: one button. See docs/features/reset-view.md.
@MainActor
final class ResetViewModel: FeatureModel {
    let bridge: VisioOneBridge

    init(bridge: VisioOneBridge) {
        self.bridge = bridge
    }

    func makePanel() -> AnyView { AnyView(ResetViewPanel(model: self)) }
}
