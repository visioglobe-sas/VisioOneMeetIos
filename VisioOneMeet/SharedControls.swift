import SwiftUI

// Small building blocks shared by several feature panels.

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

/// A capsule chip with a color swatch + name, used by every color picker
/// (custom-text-label, custom-theme, accuracy-circle-style).
struct ColorSwatchChip: View {
    let name: LocalizedStringKey
    let hex: String
    let isSelected: Bool
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 6) {
                Circle()
                    .fill(Color(hex: hex))
                    .frame(width: 14, height: 14)
                    // Keeps dark (and white) swatches visible on any panel.
                    .overlay(Circle().stroke(Color.primary.opacity(0.5), lineWidth: 1))
                Text(name)
                    .font(.subheadline)
            }
            .padding(.horizontal, 10)
            .padding(.vertical, 6)
            .background(
                Capsule().fill(isSelected ? Color.accentColor.opacity(0.2) : Color(.secondarySystemBackground))
            )
            .overlay(
                Capsule().stroke(isSelected ? Color.accentColor : Color.clear, lineWidth: 2)
            )
        }
        .buttonStyle(.plain)
        .accessibilityAddTraits(isSelected ? .isSelected : [])
    }
}

/// A text field for a POI id (or any other identifier): no autocorrection,
/// no autocapitalization.
struct PoiIdField: View {
    let title: LocalizedStringKey
    @Binding var text: String

    init(_ title: LocalizedStringKey, text: Binding<String>) {
        self.title = title
        _text = text
    }

    var body: some View {
        TextField(title, text: $text)
            .textFieldStyle(.roundedBorder)
            .autocorrectionDisabled()
            .textInputAutocapitalization(.never)
    }
}

/// The From / To (origin / destination POI id) pair used by the itinerary
/// screens (compute-navigation, custom-navigation-trace,
/// navigation-exclude-modalities, accessible-mode) and by the
/// position-tracking screens.
struct OriginDestinationFields: View {
    @Binding var origin: String
    @Binding var destination: String

    var body: some View {
        PoiIdField("From (place ID)", text: $origin)
        PoiIdField("To (place ID)", text: $destination)
    }

    /// Both ids trimmed, or `nil` when either is empty.
    static func trimmed(_ origin: String, _ destination: String) -> (origin: String, destination: String)? {
        let from = origin.trimmingCharacters(in: .whitespaces)
        let to = destination.trimmingCharacters(in: .whitespaces)
        guard !from.isEmpty, !to.isEmpty else { return nil }
        return (from, to)
    }
}
