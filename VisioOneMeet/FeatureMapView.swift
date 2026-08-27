import SwiftUI

struct FeatureMapView: View {
    let feature: Feature
    @StateObject private var bridge = VisioOneBridge()
    @State private var isControlPresented = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            MapWebView(bridge: bridge, hashOverride: feature.mapHashOverride)
                .ignoresSafeArea()

            switch bridge.loadState {
            case .loading:
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .ready:
                // poi-click has no manual trigger: the reaction panel is
                // presented automatically from the SDK's own `poiclick`
                // event (see the onChange below), so there's nothing for a
                // FAB to open here.
                if feature != .poiClick {
                    fab
                } else if bridge.tappedPOI == nil {
                    poiClickHint
                }
            case .error(let message):
                errorOverlay(message: message)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .statusBarHidden(false)
        .navigationTitle(Text(feature.title))
        .navigationBarTitleDisplayMode(.inline)
        .sheet(isPresented: $isControlPresented, onDismiss: {
            if feature == .poiClick {
                bridge.clearTappedPOI()
            }
        }) {
            overlay
                .background(Color(.systemBackground))
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .onChange(of: bridge.tappedPOI) { newValue in
            guard feature == .poiClick else { return }
            isControlPresented = newValue != nil
        }
        .onChange(of: bridge.loadState) { newValue in
            // native-ui-replacement's whole point is that the SDK's own
            // floor-selector widget starts hidden, unlike ui-part-visibility
            // (whose 5 switches leave the SDK's default alone until
            // toggled). That deviation from the SDK's own default has to be
            // enforced explicitly once `view` exists, not just implied by
            // `isSdkFloorSelectorVisible`'s initial value on the bridge —
            // see docs/features/native-ui-replacement.md.
            guard feature == .nativeUiReplacement, newValue == .ready else { return }
            bridge.setSdkFloorSelectorVisible(false)
        }
    }

    private var poiClickHint: some View {
        Text("Tap a POI on the map")
            .font(.footnote)
            .foregroundStyle(.white)
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
            .background(Capsule().fill(.black.opacity(0.6)))
            .padding(24)
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
        case .poiClick:
            PoiClickOverlay(bridge: bridge)
        case .goToPoi:
            GoToPoiOverlay(bridge: bridge)
        case .floorSelector:
            FloorSelectorOverlay(bridge: bridge)
        case .exploreMode:
            ExploreModeOverlay(bridge: bridge)
        case .computeNavigation:
            ComputeNavigationOverlay(bridge: bridge)
        case .uiPartVisibility:
            UIPartVisibilityOverlay(bridge: bridge)
        case .nativeUiReplacement:
            NativeUiReplacementOverlay(bridge: bridge)
        case .simulatedPosition:
            SimulatedPositionOverlay(bridge: bridge)
        case .cameraLockOnPosition:
            CameraLockOnPositionOverlay(bridge: bridge)
        case .clickableSurface:
            ClickableSurfaceOverlay(bridge: bridge)
        case .customData:
            CustomDataOverlay(bridge: bridge)
        case .categoryHighlight:
            CategoryHighlightOverlay(bridge: bridge)
        case .dynamicPoiCrud:
            DynamicPoiCrudOverlay(bridge: bridge)
        case .runtimeLocale:
            RuntimeLocaleOverlay(bridge: bridge)
        }
    }
}

#Preview {
    NavigationStack {
        FeatureMapView(feature: .resetView)
    }
}
