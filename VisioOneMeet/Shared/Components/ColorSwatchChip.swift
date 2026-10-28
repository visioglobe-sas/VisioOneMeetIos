import SwiftUI

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
