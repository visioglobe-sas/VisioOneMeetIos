import Foundation

extension VisioOneBridge {
    /// Computes a route like `computeNavigation`, but additionally excludes
    /// one or more segment "particularities" (e.g. elevators, stairs) from
    /// consideration via `venue.computeNavigation()`'s `excludedAttributes`
    /// option (see `docs/features/navigation-exclude-modalities.md`).
    ///
    /// On this app's shared demo venue, the attribute string for an elevator
    /// hop is `'lift'` -- *not* `'elevator'`, despite the SDK's own JSDoc
    /// comment on `excludedAttributes` (confirmed live, see the feature doc).
    /// This method takes the raw attribute strings as-is. An error thrown by
    /// `venue.computeNavigation()` (e.g. no route survives the exclusion) is
    /// logged, same as an ordinary unreachable origin/destination pair.
    func computeNavigationExcludingModalities(
        origin: String,
        destination: String,
        isAccessible: Bool,
        excludedAttributes: [String]
    ) {
        call("computeNavigationExcludingModalities", args: [[
            "origin": origin,
            "destination": destination,
            "isAccessible": isAccessible,
            "excludedAttributes": excludedAttributes,
        ]])
    }

    /// Clears whatever navigation trace is currently displayed via
    /// `view.removeCurrentNavigationTrace()`. No-op JS-side if nothing is
    /// displayed. Also used by accessible-mode.
    func clearNavigationTrace() {
        call("clearNavigationTrace")
    }
}
