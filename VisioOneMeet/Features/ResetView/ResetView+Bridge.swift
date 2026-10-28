import Foundation

extension VisioOneBridge {
    /// Recenters the camera on the venue via `view.goToGlobal()`. Silent
    /// no-op on the JS side if `view` isn't set yet (i.e. before
    /// `createView` has resolved) -- see `features/reset-view.js`.
    func goToGlobal() {
        call("goToGlobal")
    }
}
