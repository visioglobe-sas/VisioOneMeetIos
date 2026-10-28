import Foundation

extension VisioOneBridge {
    /// Sets the venue's building-exploration mode via
    /// `view.currentExploreMode` (see `docs/features/explore-mode.md`).
    /// Fire-and-forget: the mode shown natively only ever follows the JS
    /// side's `exploreModeChanged` message, never optimistically here, since
    /// the SDK can auto-switch out of `.building` mode on its own (a click
    /// switches it to `.floor`) and the native UI must reflect whatever the
    /// SDK actually lands on, not what was requested.
    func setExploreMode(_ mode: MapExploreMode) {
        call("setExploreMode", args: [mode.rawValue])
    }
}
