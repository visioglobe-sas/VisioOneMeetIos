import Foundation

extension VisioOneBridge {
    /// Adds `locale` at runtime via `venue.translator.addLocale()` with
    /// these key/value `resources`. Synchronous on the SDK side; returns
    /// `false` on a bridge/JS failure (logged). See
    /// `docs/features/add-locale.md`.
    func addLocale(_ locale: String, resources: [String: String]) async -> Bool {
        if case .success = await callForResult("addLocale", args: [locale, resources]) {
            return true
        }
        return false
    }

    /// Reads a single key back via `venue.translator.translate(key, locale)`,
    /// `""` on a bridge failure.
    func translate(_ key: String, locale: String) async -> String {
        guard case .success(let value) = await callForResult("translate", args: [key, locale]) else { return "" }
        return value as? String ?? ""
    }
}
