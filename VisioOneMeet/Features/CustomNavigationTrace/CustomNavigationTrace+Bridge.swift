import Foundation

/// Colors applicable to an already-displayed navigation trace via
/// `venue.updateNavigationTrace()`. Mirrors the SDK's
/// `NavigationTraceUpdateOptions` colors-only surface -- `textureRepeat`/
/// `animationSpeed` are omitted since they only affect the `'textured'`
/// `displayMode`, which can't be changed after `createNavigationTrace()`.
/// See `docs/features/custom-navigation-trace.md`.
struct NavigationTraceColors: Equatable {
    let progressColor: String
    let progressOutlineColor: String
    let progressFutureColor: String
    let previewColor: String
    let previewOutlineColor: String
}

extension VisioOneBridge {
    /// Restyles the currently displayed navigation trace (if any) via
    /// `venue.updateNavigationTrace()`. Colors only -- there is no way to
    /// change `displayMode`/`thickness` after `createNavigationTrace()`.
    /// No-op JS-side if `computeNavigation` hasn't created a trace yet.
    ///
    /// The JS side swallows an internal SDK `TypeError` this call is known
    /// to throw against this app's shared demo venue (see
    /// `features/custom-navigation-trace.js`), so a failure logged here is
    /// only ever an actual bridge failure, never that quirk.
    func updateNavigationTrace(_ colors: NavigationTraceColors) {
        call("updateNavigationTrace", args: [[
            "progressColor": colors.progressColor,
            "progressOutlineColor": colors.progressOutlineColor,
            "progressFutureColor": colors.progressFutureColor,
            "previewColor": colors.previewColor,
            "previewOutlineColor": colors.previewOutlineColor,
        ]])
    }
}
