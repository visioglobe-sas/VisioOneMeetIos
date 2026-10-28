import SwiftUI

extension Color {
    /// `#RRGGBB` -> SwiftUI color, for swatches drawn by the native panels.
    /// The colors sent to the SDK stay hex strings; this is display only.
    init(hex: String) {
        var sanitized = hex.trimmingCharacters(in: .whitespacesAndNewlines)
        if sanitized.hasPrefix("#") { sanitized.removeFirst() }
        let value = UInt32(sanitized, radix: 16) ?? 0
        self.init(
            red: Double((value >> 16) & 0xFF) / 255,
            green: Double((value >> 8) & 0xFF) / 255,
            blue: Double(value & 0xFF) / 255
        )
    }
}
