import SwiftUI

/// Switches the 3D scene lighting theme via `view.setTheme()` -- the choices
/// are built at runtime from `view.themes`, shown as raw SDK ids -- and
/// recolors the SDK's own UI buttons via `view.accentColor` /
/// `view.textAccentColor`. Everything applies immediately and is kept on the
/// model, so it survives closing the sheet (needed to tap a place and see
/// its card's Go button). See docs/features/custom-theme.md.
struct CustomThemePanel: View {
    @ObservedObject var model: CustomThemeModel

    private var theme: Binding<String> {
        Binding(get: { model.currentTheme }, set: { model.setTheme($0) })
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                Text("Theme")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                if model.themes.isEmpty {
                    ProgressView()
                } else {
                    Picker("Theme", selection: theme) {
                        ForEach(model.themes, id: \.self) { name in
                            Text(name).tag(name)
                        }
                    }
                    .pickerStyle(.segmented)
                }

                Text("Accent color")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    ForEach(ThemeAccentColor.allCases) { color in
                        ColorSwatchChip(
                            name: Self.name(color),
                            hex: color.rawValue,
                            isSelected: model.accentColor == color
                        ) {
                            model.setAccentColor(color)
                        }
                    }
                }

                Text("Accent text color")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    ForEach(ThemeTextAccentColor.allCases) { color in
                        ColorSwatchChip(
                            name: Self.name(color),
                            hex: color.rawValue,
                            isSelected: model.textAccentColor == color
                        ) {
                            model.setTextAccentColor(color)
                        }
                    }
                }

                Button("Reset") {
                    model.reset()
                }
                .buttonStyle(.bordered)

                Text("feature.custom_theme.hint")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
        .task {
            if model.themes.isEmpty {
                await model.loadThemes()
            }
        }
    }

    private static func name(_ color: ThemeAccentColor) -> LocalizedStringKey {
        switch color {
        case .blue: return "Blue"
        case .red: return "Red"
        case .green: return "Green"
        case .purple: return "Purple"
        }
    }

    private static func name(_ color: ThemeTextAccentColor) -> LocalizedStringKey {
        switch color {
        case .white: return "White"
        case .yellow: return "Yellow"
        case .black: return "Black"
        }
    }
}
