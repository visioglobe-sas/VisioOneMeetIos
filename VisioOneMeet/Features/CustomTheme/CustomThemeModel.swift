import SwiftUI

/// Accent color choices for the SDK's own UI buttons (POI card "Go", "Add a
/// step"...). Raw values are the hex strings assigned as-is to
/// `view.accentColor` (hex, `rgba()` or `hsl()` only -- anything else
/// throws). `.blue` is the SDK default. See `docs/features/custom-theme.md`.
enum ThemeAccentColor: String, CaseIterable, Identifiable {
    case blue = "#0094F0"
    case red = "#E53935"
    case green = "#43A047"
    case purple = "#8E24AA"

    var id: String { rawValue }
}

/// Text color choices for those same SDK buttons, assigned as-is to
/// `view.textAccentColor`. `.white` is the SDK default.
enum ThemeTextAccentColor: String, CaseIterable, Identifiable {
    case white = "#FFFFFF"
    case yellow = "#FFEB3B"
    case black = "#212121"

    var id: String { rawValue }
}

/// Theme / accent colors currently applied, kept here -- not in the panel --
/// so they survive the panel being dismissed and reopened. The SDK has no
/// current-theme getter, so the theme is tracked here, starting at the SDK
/// default `"day"`. This screen's view is created with `enableShadows: true`
/// (see `Feature.all`).
@MainActor
final class CustomThemeModel: ObservableObject, FeatureModel {
    static let defaultTheme = "day"

    /// Scene themes registered on the view (`view.themes`), read once via
    /// `loadThemes()` -- empty until then.
    @Published private(set) var themes: [String] = []
    @Published private(set) var currentTheme = CustomThemeModel.defaultTheme
    @Published private(set) var accentColor: ThemeAccentColor = .blue
    @Published private(set) var textAccentColor: ThemeTextAccentColor = .white

    let bridge: VisioOneBridge

    init(bridge: VisioOneBridge) {
        self.bridge = bridge
        bridge.onReload { [weak self] in
            self?.themes = []
            self?.currentTheme = Self.defaultTheme
            self?.accentColor = .blue
            self?.textAccentColor = .white
        }
    }

    func makePanel() -> AnyView { AnyView(CustomThemePanel(model: self)) }

    func loadThemes() async {
        if let result = await bridge.getThemes() {
            themes = result
        }
    }

    /// Updates `currentTheme` optimistically and rolls it back if the SDK
    /// throws.
    func setTheme(_ name: String) {
        guard bridge.webView != nil else { return }
        let previous = currentTheme
        currentTheme = name
        Task {
            if await bridge.setTheme(name) != .success {
                currentTheme = previous
            }
        }
    }

    func setAccentColor(_ color: ThemeAccentColor) {
        accentColor = color
        bridge.setAccentColors(accent: color.rawValue, text: nil)
    }

    func setTextAccentColor(_ color: ThemeTextAccentColor) {
        textAccentColor = color
        bridge.setAccentColors(accent: nil, text: color.rawValue)
    }

    /// Back to the SDK defaults: theme `"day"`, accent `#0094F0`, text
    /// accent `#FFFFFF`.
    func reset() {
        setTheme(Self.defaultTheme)
        accentColor = .blue
        textAccentColor = .white
        bridge.setAccentColors(accent: ThemeAccentColor.blue.rawValue, text: ThemeTextAccentColor.white.rawValue)
    }
}
