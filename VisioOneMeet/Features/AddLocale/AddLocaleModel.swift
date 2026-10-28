import SwiftUI

@MainActor
final class AddLocaleModel: ObservableObject, FeatureModel {
    /// The two keys `addSpanishLocale()` adds and reads back via `translate`,
    /// in display order: `'search-for-anything'` is one of the SDK's own
    /// predefined UI keys (listed in `addLocale`'s API reference), showing
    /// `addLocale` can override the SDK's own built-in UI text;
    /// `'welcome-message'` is a key the SDK itself has no built-in meaning
    /// for, showing this is a general-purpose key/value store also usable for
    /// the app's own strings. See `docs/features/add-locale.md`.
    static let keys = ["search-for-anything", "welcome-message"]

    /// Fixed Spanish resources for `keys`, added at runtime via
    /// `venue.translator.addLocale('es', ...)`.
    private static let spanishResources: [String: String] = [
        "search-for-anything": "Busca lo que quieras",
        "welcome-message": "¡Bienvenido a VisioOne!",
    ]

    /// `nil` until `addSpanishLocale()` succeeds; then one entry per `keys`,
    /// holding `venue.translator.translate(key, 'es')`'s value -- the
    /// primary, always-working proof the round trip succeeded, regardless of
    /// whether any of the SDK's own default UI parts happen to be visible.
    @Published private(set) var spanishTranslations: [String: String]?

    let bridge: VisioOneBridge

    init(bridge: VisioOneBridge) {
        self.bridge = bridge
        bridge.onReload { [weak self] in self?.spanishTranslations = nil }
    }

    func makePanel() -> AnyView { AnyView(AddLocalePanel(model: self)) }

    /// Adds the `'es'` locale -- one never authored in VisioMapEditor for
    /// this map -- then reads each of `keys` back to populate
    /// `spanishTranslations`, only once the add has returned.
    func addSpanishLocale() async {
        guard await bridge.addLocale("es", resources: Self.spanishResources) else { return }

        var results: [String: String] = [:]
        for key in Self.keys {
            results[key] = await bridge.translate(key, locale: "es")
        }
        spanishTranslations = results
    }

    /// runtime-locale's exact call, so any visible SDK UI text updates live
    /// too.
    func switchToSpanish() async {
        await bridge.setCurrentLocale("es")
    }
}
