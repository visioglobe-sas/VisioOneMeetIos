import SwiftUI

/// Color presets for the tracked position's precision circle, passed as-is
/// to `view.updatePositionTrackerGraphicOptions({ color })` (hex, `rgba()`
/// or `hsl()` only -- anything else throws). `.defaultBlue` is the SDK
/// default. See `docs/features/accuracy-circle-style.md`.
enum PositionTrackerColor: String, CaseIterable, Identifiable {
    case defaultBlue = "#0094f0"
    case red = "#e53935"
    case green = "#43a047"
    case purple = "#8e24aa"

    var id: String { rawValue }
}

/// The simulated tracked position (a `PositionTrackingController` with a
/// 6 m radius) plus its selected style. The SDK has no getter for its
/// position-tracker graphic options, so the style lives here; it starts at
/// the SDK defaults (`#0094f0`, 0.3), and is re-sent before the first inject
/// of each Start (`onWillStartTracking`), since the SDK resets it whenever
/// tracking stops.
@MainActor
final class AccuracyCircleStyleModel: ObservableObject, FeatureModel {
    @Published private(set) var color: PositionTrackerColor = .defaultBlue
    @Published private(set) var opacity: Double = 0.3

    let bridge: VisioOneBridge
    let tracking: PositionTrackingController

    init(bridge: VisioOneBridge) {
        self.bridge = bridge
        tracking = PositionTrackingController(bridge: bridge, precisionCircleRadius: 6)
        tracking.onWillStartTracking = { [weak self] in
            self?.applyStyle()
        }
        bridge.onReload { [weak tracking] in tracking?.stopIfRunning() }
    }

    func makePanel() -> AnyView { AnyView(AccuracyCircleStylePanel(model: self, tracking: tracking)) }

    func screenDidDisappear() {
        tracking.stopIfRunning()
    }

    func setColor(_ newValue: PositionTrackerColor) {
        color = newValue
        applyStyle()
    }

    /// Rounded to one decimal (the slider's step).
    func setOpacity(_ newValue: Double) {
        opacity = (newValue * 10).rounded() / 10
        applyStyle()
    }

    private func applyStyle() {
        bridge.updatePositionTrackerGraphicOptions(color: color.rawValue, opacity: opacity)
    }
}
