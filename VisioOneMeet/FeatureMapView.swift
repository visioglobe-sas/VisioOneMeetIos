import SwiftUI

struct FeatureMapView: View {
    let feature: Feature
    @StateObject private var bridge = VisioOneBridge()

    var body: some View {
        ZStack(alignment: .bottom) {
            MapWebView(bridge: bridge)
                .ignoresSafeArea()

            overlay
        }
        .statusBarHidden(false)
        .navigationTitle(Text(feature.title))
        .navigationBarTitleDisplayMode(.inline)
    }

    @ViewBuilder
    private var overlay: some View {
        switch feature {
        case .resetView:
            ResetViewOverlay(bridge: bridge)
        case .occupancySimulated:
            OccupancyOverlay(bridge: bridge)
        }
    }
}

#Preview {
    NavigationStack {
        FeatureMapView(feature: .resetView)
    }
}
