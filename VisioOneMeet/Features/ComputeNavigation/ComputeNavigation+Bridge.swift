import Foundation

extension VisioOneBridge {
    /// Computes a route between two POIs (by ID) and displays it, via
    /// `venue.computeNavigation()` + `venue.createNavigationTrace()` +
    /// `view.setCurrentNavigationTrace()` (see
    /// `docs/features/compute-navigation.md`). Computing a new route while
    /// one is already displayed replaces it automatically -- no explicit
    /// "clear" is needed. Also used by custom-navigation-trace and
    /// accessible-mode (`isAccessible`). An error thrown by
    /// `venue.computeNavigation()` (e.g. no route) is logged.
    func computeNavigation(origin: String, destination: String, isAccessible: Bool) {
        call("computeNavigation", args: [
            ["origin": origin, "destination": destination, "isAccessible": isAccessible],
        ])
    }
}
