import SwiftUI

/// Demonstrates that the app's own native floor/building picker -- reused
/// verbatim via `FloorSelectorList`, not reimplemented -- is a complete,
/// fully-functional replacement for the SDK's own default floor-selector
/// widget, via `view.setUIPartVisible('floorSelector', ...)`. The SDK widget
/// starts hidden (`NativeUiReplacementModel.mapDidBecomeReady()`), so only
/// the app's picker is visible/functional by default; the "Show SDK's own
/// floor selector" toggle below reveals the SDK's widget alongside it, both
/// driven by the exact same `currentfloorchanged` event, so a visitor can
/// compare the two live rather than take the replacement on faith. The
/// native picker above stays fully functional regardless of the toggle's
/// state -- that's the actual point being demonstrated. See
/// docs/features/native-ui-replacement.md.
struct NativeUiReplacementPanel: View {
    let floors: FloorSelectorModel
    @ObservedObject var uiParts: UiPartVisibilityModel

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            FloorSelectorList(model: floors)

            Divider()

            Toggle(isOn: sdkWidgetVisibleBinding) {
                Text("feature.native_ui_replacement.toggle")
            }
            .padding()
        }
    }

    private var sdkWidgetVisibleBinding: Binding<Bool> {
        Binding(
            get: { uiParts.isVisible(.floorSelector) },
            set: { uiParts.setVisible(.floorSelector, $0) }
        )
    }
}
