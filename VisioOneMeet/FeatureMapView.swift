import SwiftUI

struct FeatureMapView: View {
    let feature: Feature
    @StateObject private var bridge = VisioOneBridge()
    @State private var isControlPresented = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            MapWebView(bridge: bridge)
                .ignoresSafeArea()

            Button {
                isControlPresented = true
            } label: {
                Image(systemName: "slider.horizontal.3")
                    .font(.title2)
                    .foregroundStyle(.white)
                    .frame(width: 56, height: 56)
                    .background(Circle().fill(Color.accentColor))
                    .shadow(radius: 6, y: 3)
            }
            .padding(24)
        }
        .statusBarHidden(false)
        .navigationTitle(Text(feature.title))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isControlPresented) {
            overlay
                .background(Color(.systemBackground))
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
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
