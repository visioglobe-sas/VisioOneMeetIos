import Foundation

extension VisioOneBridge {
    /// Reads `view.themes`, the scene themes registered on the view; `nil`
    /// on a bridge failure. See `docs/features/custom-theme.md`.
    func getThemes() async -> [String]? {
        guard case .success(let value) = await callForResult("getThemes") else { return nil }
        return value as? [String]
    }

    /// Switches the 3D scene lighting via `view.setTheme(name)`; the SDK
    /// throws on an id not in `view.themes`, reported as a normal result.
    func setTheme(_ name: String) async -> BridgeResult {
        await callForStatus("setTheme", args: [name])
    }

    /// Recolors the SDK's UI buttons via `view.accentColor` (background) and
    /// `view.textAccentColor` (text); `nil` leaves that color alone.
    func setAccentColors(accent: String?, text: String?) {
        callReportingStatus("setAccentColors", args: [accent, text])
    }
}
