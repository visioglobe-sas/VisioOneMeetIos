import SwiftUI

/// Lets the user show/hide each of the SDK's own default UI overlays via
/// `view.setUIPartVisible()`. All 5 toggles default to on/visible, matching
/// the SDK's own default -- nothing is hidden until the user flips a switch.
/// The switches mirror `model.hiddenUIParts` (the SDK has no getter), so
/// they still show the map's real state after the panel is reopened.
/// See docs/features/ui-part-visibility.md.
struct UiPartVisibilityPanel: View {
    @ObservedObject var model: UiPartVisibilityModel

    var body: some View {
        List(MapUIPart.allCases) { part in
            Toggle(isOn: binding(for: part)) {
                Text(part.title)
            }
        }
        .listStyle(.plain)
    }

    private func binding(for part: MapUIPart) -> Binding<Bool> {
        Binding(
            get: { model.isVisible(part) },
            set: { model.setVisible(part, $0) }
        )
    }
}
