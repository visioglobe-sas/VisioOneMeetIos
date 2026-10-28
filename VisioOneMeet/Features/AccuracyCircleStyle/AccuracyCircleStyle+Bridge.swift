import Foundation

extension VisioOneBridge {
    /// Pushes a color/opacity to
    /// `view.updatePositionTrackerGraphicOptions({ color, opacity })`. The
    /// SDK only stores them -- they're drawn at the next
    /// `injectTrackedPosition` -- and resets them to its defaults whenever
    /// tracking stops. Safe to call while not tracking; a failure is logged.
    /// See `docs/features/accuracy-circle-style.md`.
    func updatePositionTrackerGraphicOptions(color: String, opacity: Double) {
        callReportingStatus("updatePositionTrackerGraphicOptions", args: [color, opacity])
    }
}
