import SwiftUI

struct FeatureMapView: View {
    let feature: Feature
    @StateObject private var bridge = VisioOneBridge()
    @State private var isControlPresented = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            MapWebView(bridge: bridge)
                .ignoresSafeArea()

            switch bridge.loadState {
            case .loading:
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .ready:
                fab
            case .error(let message):
                errorOverlay(message: message)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
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

    private var fab: some View {
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

    private func errorOverlay(message: String) -> some View {
        VStack(spacing: 16) {
            Text("Impossible de charger la carte VisioOne")
                .font(.headline)
                .foregroundColor(.white)
            Text(message)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
            Button("Réessayer") {
                bridge.reload()
            }
            .buttonStyle(.borderedProminent)
        }
        .padding(24)
        .frame(maxWidth: .infinity)
        .background(Color.black.opacity(0.85))
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
