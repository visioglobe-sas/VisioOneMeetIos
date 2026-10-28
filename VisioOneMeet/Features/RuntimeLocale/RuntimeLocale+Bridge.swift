import Foundation

extension VisioOneBridge {
    /// Reads the venue's current locale (`venue.currentLocale`), `nil` on a
    /// bridge failure. See `docs/features/runtime-locale.md`.
    func getCurrentLocale() async -> String? {
        guard case .success(let value) = await callForResult("getCurrentLocale") else { return nil }
        return value as? String
    }

    /// Switches the map's displayed locale via `venue.setCurrentLocale()`,
    /// which returns a Promise the SDK itself awaits before re-rendering
    /// every POI/label's text (and any current View UI) for the new locale --
    /// no manual re-fetch of POI data is needed on this side. Returns once
    /// that promise has settled: `false` on a bridge/JS failure (logged).
    /// Also used by add-locale.
    @discardableResult
    func setCurrentLocale(_ locale: String) async -> Bool {
        if case .success = await callForResult("setCurrentLocale", args: [locale]) {
            return true
        }
        return false
    }
}
