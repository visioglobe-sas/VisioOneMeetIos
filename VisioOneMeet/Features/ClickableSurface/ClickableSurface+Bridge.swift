import Foundation

extension VisioOneBridge {
    /// Makes a POI's surface(s) clickable via `venue.updateSurface()`'s
    /// `isInteractive` option, letting the SDK itself swap the displayed
    /// color on hover/tap (`hoverColor`/`selectionColor`) -- no click
    /// listener is needed on either side of the bridge for that part (see
    /// `docs/features/clickable-surface.md`). Disabling resets the base
    /// color to `'initial'` so the surface doesn't stay stuck on the custom
    /// color set while enabled.
    func setSurfaceInteractive(_ poiId: String, isInteractive: Bool) {
        call("setSurfaceInteractive", args: [poiId, isInteractive])
    }
}
