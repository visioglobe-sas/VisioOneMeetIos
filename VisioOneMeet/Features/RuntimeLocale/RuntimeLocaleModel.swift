import SwiftUI

/// One switchable locale option offered by `RuntimeLocalePanel`. The shared
/// demo map's `venue.translator.allLocales` is `['en', 'fr']`; `'default'`
/// isn't even listed there, yet it's still a working locale value that
/// renders byte-identical POI/label text to `'fr'` on this map (both French)
/// -- confirmed live. It's deliberately not offered here as a third,
/// meaningfully-different choice. See docs/features/runtime-locale.md.
struct MapLocaleOption: Identifiable {
    let code: String
    let label: String
    var id: String { code }
}

@MainActor
final class RuntimeLocaleModel: ObservableObject, FeatureModel {
    static let options = [
        MapLocaleOption(code: "en", label: "English"),
        MapLocaleOption(code: "fr", label: "Français"),
    ]

    /// The venue's current locale (`venue.currentLocale`), `nil` until first
    /// read via `refreshCurrentLocale()`. Never set optimistically:
    /// `switchLocale` only updates it once the SDK's own
    /// `venue.setCurrentLocale()` promise resolves.
    @Published private(set) var currentLocale: String?

    let bridge: VisioOneBridge

    init(bridge: VisioOneBridge) {
        self.bridge = bridge
        bridge.onReload { [weak self] in self?.currentLocale = nil }
    }

    func makePanel() -> AnyView { AnyView(RuntimeLocalePanel(model: self)) }

    func refreshCurrentLocale() async {
        if let locale = await bridge.getCurrentLocale() {
            currentLocale = locale
        }
    }

    func switchLocale(to code: String) async {
        if await bridge.setCurrentLocale(code) {
            currentLocale = code
        }
    }
}
