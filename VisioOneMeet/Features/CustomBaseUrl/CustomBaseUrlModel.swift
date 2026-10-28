import SwiftUI

/// The base URL itself is a page option (`bridge.pageOptions.baseURL`), so
/// it survives the reload it triggers; this screen keeps no other state.
@MainActor
final class CustomBaseUrlModel: FeatureModel {
    /// The SDK's own default `baseURL` (`LoadOptions.baseURL`'s default) --
    /// the root every other feature implicitly loads map data from. This
    /// screen starts from it (see `Feature.all`).
    nonisolated static let sdkDefaultBaseURL = "https://mapserver.visioglobe.com/"

    let bridge: VisioOneBridge

    init(bridge: VisioOneBridge) {
        self.bridge = bridge
    }

    func makePanel() -> AnyView { AnyView(CustomBaseUrlPanel(bridge: bridge)) }
}
