import SwiftUI

struct FeatureMapView: View {
    let feature: Feature

    var body: some View {
        if feature == .authToken {
            // Code sample only: no map is loaded on this screen.
            AuthTokenSampleScreen(feature: feature)
        } else {
            FeatureScreen(feature: feature)
        }
    }
}

/// auth-token: a plain text page pointing to the code sample
/// (`ProtectedMapSample.swift` + `loadProtectedVenue()` in `map.html`). This
/// demo has no protected map, so nothing is loaded here. See
/// `docs/features/auth-token.md`.
private struct AuthTokenSampleScreen: View {
    let feature: Feature

    var body: some View {
        ScrollView {
            Text("feature.auth_token.screen_text")
                .font(.body)
                .textSelection(.enabled)
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(24)
        }
        .background(Color(.systemBackground))
        .navigationTitle(Text(feature.title))
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// The feature screen itself, one per map. Every piece of state the
/// control panel shows is owned here (or on the bridge), never inside the
/// `.sheet` content, which is recreated each time it opens: the values typed
/// in the panel (`inputs`), the occupancy and position-tracking loops, the
/// geofencing zone. So closing the panel to look at the map and reopening
/// it shows the real current state, there is only ever one loop per screen,
/// and leaving the screen stops everything. (The camera-showcase-carousel
/// loop follows the same rule from the page itself, its state mirrored on
/// the bridge.)
private struct FeatureScreen: View {
    let feature: Feature
    @StateObject private var bridge: VisioOneBridge
    @StateObject private var inputs: FeatureInputs
    @StateObject private var tracking: PositionTrackingController
    @StateObject private var geofence: GeofencingViewModel
    @StateObject private var occupancy: OccupancySimulationController
    @State private var isControlPresented = false

    init(feature: Feature) {
        self.feature = feature
        let bridge = VisioOneBridge()
        _bridge = StateObject(wrappedValue: bridge)
        _inputs = StateObject(wrappedValue: FeatureInputs(feature: feature))
        _tracking = StateObject(wrappedValue: PositionTrackingController.forFeature(feature, bridge: bridge))
        _geofence = StateObject(wrappedValue: GeofencingViewModel(bridge: bridge))
        _occupancy = StateObject(wrappedValue: OccupancySimulationController(bridge: bridge))
    }

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            MapWebView(
                bridge: bridge,
                mapHash: feature.mapHash,
                baseURLOverride: feature == .customBaseUrl ? bridge.baseURL : nil,
                enableShadows: feature.enableShadows,
                cameraProjection: feature == .cameraProjectionToggle ? bridge.requestedCameraProjection : nil
            )
            // Recreates the WKWebView (fresh loadVenue + createView) when
            // either load/creation-time option changes.
            .id("\(bridge.baseURL)|\(bridge.requestedCameraProjection.rawValue)")
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
            // toggled): hide it explicitly once `view` exists. See
            // docs/features/native-ui-replacement.md.
            guard feature == .nativeUiReplacement, newValue == .ready else { return }
            bridge.setSdkFloorSelectorVisible(false)
        }
        .onAppear {
            guard feature == .geofencing else { return }
            tracking.onTick = { [weak geofence] position in
                geofence?.handleTrackedPosition(position)
            }
        }
        .onChange(of: tracking.isSimulating) { simulating in
            guard feature == .geofencing, !simulating else { return }
            geofence.resetAlert()
        }
        .onDisappear {
            // Back to the menu: the map is recreated per screen, so the
            // simulations must not outlive this one.
            tracking.stopIfRunning()
            occupancy.stopIfRunning()
            // Same for the camera tour, whose loop lives in the page: stop
            // it explicitly rather than relying on the WKWebView teardown.
            if feature == .cameraShowcaseCarousel {
                bridge.stopCarousel()
            }
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
            Text("Could not load the VisioOne map")
                .font(.headline)
                .foregroundColor(.white)
            Text(verbatim: message)
                .font(.subheadline)
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
            Button("Retry") {
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
            OccupancyOverlay(controller: occupancy)
        case .poiClick:
            PoiClickOverlay(bridge: bridge)
        case .goToPoi:
            GoToPoiOverlay(bridge: bridge, inputs: inputs)
        case .floorSelector:
            FloorSelectorOverlay(bridge: bridge)
        case .exploreMode:
            ExploreModeOverlay(bridge: bridge)
        case .computeNavigation:
            ComputeNavigationOverlay(bridge: bridge, inputs: inputs)
        case .uiPartVisibility:
            UIPartVisibilityOverlay(bridge: bridge)
        case .nativeUiReplacement:
            NativeUiReplacementOverlay(bridge: bridge)
        case .simulatedPosition:
            SimulatedPositionOverlay(controller: tracking)
        case .cameraLockOnPosition:
            CameraLockOnPositionOverlay(bridge: bridge, controller: tracking)
        case .clickableSurface:
            ClickableSurfaceOverlay(bridge: bridge, inputs: inputs)
        case .customData:
            CustomDataOverlay(bridge: bridge, inputs: inputs)
        case .categoryHighlight:
            CategoryHighlightOverlay(bridge: bridge)
        case .dynamicPoiCrud:
            DynamicPoiCrudOverlay(bridge: bridge, inputs: inputs)
        case .runtimeLocale:
            RuntimeLocaleOverlay(bridge: bridge)
        case .addLocale:
            AddLocaleOverlay(bridge: bridge)
        case .geofencing:
            GeofencingOverlay(trackingController: tracking, geofence: geofence)
        case .customBaseUrl:
            CustomBaseUrlOverlay(bridge: bridge)
        case .customNavigationTrace:
            CustomNavigationTraceOverlay(bridge: bridge, inputs: inputs)
        case .navigationExcludeModalities:
            NavigationExcludeModalitiesOverlay(bridge: bridge, inputs: inputs)
        case .accessibleMode:
            AccessibleModeOverlay(bridge: bridge, inputs: inputs)
        case .iconMarker3D:
            IconMarkerOverlay(bridge: bridge, inputs: inputs)
        case .customTextLabel:
            CustomTextLabelOverlay(bridge: bridge, inputs: inputs)
        case .htmlOverlayMarker:
            HtmlOverlayMarkerOverlay(bridge: bridge, inputs: inputs)
        case .customTheme:
            CustomThemeOverlay(bridge: bridge)
        case .accuracyCircleStyle:
            AccuracyCircleStyleOverlay(bridge: bridge, controller: tracking)
        case .cameraProjectionToggle:
            CameraProjectionOverlay(bridge: bridge)
        case .cameraShowcaseCarousel:
            CameraShowcaseCarouselOverlay(bridge: bridge)
        case .authToken:
            // Not a map screen: FeatureMapView shows AuthTokenSampleScreen.
            EmptyView()
        }
    }
}

#Preview {
    NavigationStack {
        FeatureMapView(feature: .resetView)
    }
}

