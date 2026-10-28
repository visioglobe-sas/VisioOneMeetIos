import SwiftUI

/// Recolors the simulated tracked position's precision circle live via
/// `view.updatePositionTrackerGraphicOptions({ color, opacity })`, on top of
/// the same Origin/Destination POI ID + accuracy + Start/Stop controls as
/// simulated-position (shared `PositionTrackingController`/
/// `PositionTrackingControls`). See `docs/features/accuracy-circle-style.md`.
struct AccuracyCircleStylePanel: View {
    @ObservedObject var model: AccuracyCircleStyleModel
    @ObservedObject var tracking: PositionTrackingController

    private var opacity: Binding<Double> {
        Binding(
            get: { model.opacity },
            set: { model.setOpacity($0) }
        )
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 12) {
                PositionTrackingControls(controller: tracking)

                Divider()

                Text("feature.accuracy_circle_style.color")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                HStack(spacing: 8) {
                    ForEach(PositionTrackerColor.allCases) { color in
                        ColorSwatchChip(
                            name: Self.name(color),
                            hex: color.rawValue,
                            isSelected: model.color == color
                        ) {
                            model.setColor(color)
                        }
                    }
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("feature.accuracy_circle_style.opacity \(String(format: "%.1f", model.opacity))")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                    Slider(value: opacity, in: 0.1...1.0, step: 0.1)
                }

                Text("feature.accuracy_circle_style.hint")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
    }

    private static func name(_ color: PositionTrackerColor) -> LocalizedStringKey {
        switch color {
        case .defaultBlue: return "feature.accuracy_circle_style.color.default"
        case .red: return "feature.accuracy_circle_style.color.red"
        case .green: return "feature.accuracy_circle_style.color.green"
        case .purple: return "feature.accuracy_circle_style.color.purple"
        }
    }
}
