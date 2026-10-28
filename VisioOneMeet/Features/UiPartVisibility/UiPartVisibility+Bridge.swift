import Foundation

extension VisioOneBridge {
    /// Shows/hides one of the SDK's own default UI overlays via
    /// `view.setUIPartVisible()` (see `docs/features/ui-part-visibility.md`).
    /// Also used by native-ui-replacement.
    func setUIPartVisible(_ part: MapUIPart, isVisible: Bool) {
        call("setUIPartVisible", args: [part.rawValue, isVisible])
    }
}
