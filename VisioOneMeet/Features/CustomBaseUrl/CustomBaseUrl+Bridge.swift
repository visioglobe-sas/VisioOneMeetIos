import Foundation

extension VisioOneBridge {
    /// Re-loads the venue against a caller-supplied `baseURL`. Unlike every
    /// other feature call, `baseURL` is a `loadVenue` option, not a property
    /// on an already-loaded venue/view, so this can't just call into the
    /// existing page: it redoes the whole page load (see
    /// `reloadPage(with:)`), with the new `?baseURL=` query item. Retrying
    /// the exact same value reloads the page as is. See
    /// `docs/features/custom-base-url.md`.
    func reloadWithBaseURL(_ newBaseURL: String) {
        var options = pageOptions
        options.baseURL = newBaseURL
        reloadPage(with: options)
    }
}
