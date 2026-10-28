import SwiftUI

/// Lets the user switch the venue's building-exploration mode among the
/// SDK's 3 states (Global / Building / Floor) via `view.currentExploreMode`,
/// and keeps the active segment synced with the live SDK state even when it
/// changes from direct camera/map interaction rather than a tap here.
/// "Building" mode is the flagship visual effect this feature exists to show
/// off: every opened building's floors exploded into a cross-section-like
/// carousel -- the hint text below is there to make that easy to trigger for
/// a demo audience, not just technically reachable. See
/// docs/features/explore-mode.md.
struct ExploreModePanel: View {
    @ObservedObject var model: ExploreModeModel

    var body: some View {
        VStack(alignment: .leading, spacing: 16) {
            Picker("Explore mode", selection: exploreModeBinding) {
                Text("Global").tag(MapExploreMode.global)
                Text("Building").tag(MapExploreMode.building)
                Text("Floor").tag(MapExploreMode.floor)
            }
            .pickerStyle(.segmented)

            Text(hint)
                .font(.footnote)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
        }
        .padding()
    }

    private var hint: LocalizedStringKey {
        switch model.currentExploreMode {
        case .global:
            return "Normal outside view. Fly the camera into a building to open it, or tap \"Building\" now for the exploded floor carousel."
        case .building:
            return "Every opened building's floors are shown exploded, cross-section style. Tap a floor on the map to jump straight to it (switches to Floor mode automatically)."
        case .floor:
            return "Only the current floor is shown. Tap \"Building\" to go back to the exploded carousel."
        }
    }

    private var exploreModeBinding: Binding<MapExploreMode> {
        Binding(
            get: { model.currentExploreMode },
            set: { model.bridge.setExploreMode($0) }
        )
    }
}
