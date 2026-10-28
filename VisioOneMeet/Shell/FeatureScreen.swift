import Combine
import SwiftUI

/// The screen of one feature: a map screen (map + FAB + control panel), or a
/// feature's own screen (`Feature.Content.screen`).
struct FeatureScreen: View {
    let feature: Feature

    var body: some View {
        switch feature.content {
        case .map(let makeModel):
            FeatureMapScreen(feature: feature, makeModel: makeModel)
        case .screen(let makeScreen):
            makeScreen(feature)
        }
    }
}

/// The bridge and the feature model of one map screen, created together
/// once per screen.
@MainActor
private final class FeatureSession: ObservableObject {
    let bridge: VisioOneBridge
    let model: FeatureModel

    init(feature: Feature, makeModel: (VisioOneBridge) -> FeatureModel) {
        bridge = VisioOneBridge(pageOptions: feature.pageOptions)
        model = makeModel(bridge)
    }
}

/// One map per screen. Every piece of state the control panel shows is
/// owned by the feature model (see `FeatureModel`), never by the `.sheet`
/// content, which is recreated each time it opens.
private struct FeatureMapScreen: View {
    let feature: Feature
    @StateObject private var session: FeatureSession

    init(feature: Feature, makeModel: @escaping (VisioOneBridge) -> FeatureModel) {
        self.feature = feature
        _session = StateObject(wrappedValue: FeatureSession(feature: feature, makeModel: makeModel))
    }

    var body: some View {
        FeatureMapContent(feature: feature, bridge: session.bridge, model: session.model)
    }
}

private struct FeatureMapContent: View {
    let feature: Feature
    @ObservedObject var bridge: VisioOneBridge
    let model: FeatureModel
    @State private var isControlPresented = false

    var body: some View {
        ZStack(alignment: .bottomTrailing) {
            MapWebView(
                bridge: bridge,
                mapHash: bridge.pageOptions.mapHash,
                baseURLOverride: bridge.pageOptions.baseURL,
                enableShadows: bridge.pageOptions.enableShadows,
                cameraProjection: bridge.pageOptions.cameraProjection
            )
            // Recreates the WKWebView (fresh loadVenue + createView) when a
            // load/creation-time option changes.
            .id(bridge.pageOptions)
            .ignoresSafeArea()

            switch bridge.loadState {
            case .loading:
                ProgressView()
                    .tint(.white)
                    .scaleEffect(1.5)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            case .ready:
                switch model.panelTrigger {
                case .fab:
                    fab
                case .automatic(_, let hint):
                    if !isControlPresented {
                        mapHint(hint)
                    }
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
            model.panelDidDismiss()
        }) {
            model.makePanel()
                .background(Color(.systemBackground))
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .onReceive(panelRequests) { isRequested in
            isControlPresented = isRequested
        }
        .onChange(of: bridge.loadState) { newValue in
            guard newValue == .ready else { return }
            model.mapDidBecomeReady()
        }
        .onDisappear {
            // Back to the menu: the map is recreated per screen, so nothing
            // the feature runs may outlive this one.
            model.screenDidDisappear()
        }
    }

    private var panelRequests: AnyPublisher<Bool, Never> {
        if case .automatic(let requests, _) = model.panelTrigger {
            return requests
        }
        return Empty().eraseToAnyPublisher()
    }

    private func mapHint(_ hint: LocalizedStringKey) -> some View {
        Text(hint)
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
}

#Preview {
    NavigationStack {
        FeatureScreen(feature: Feature.all[0])
    }
}
