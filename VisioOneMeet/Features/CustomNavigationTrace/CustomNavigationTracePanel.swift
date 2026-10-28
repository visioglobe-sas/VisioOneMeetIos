import SwiftUI

/// Restyles the route drawn by compute-navigation with a fixed color
/// palette via `venue.updateNavigationTrace()`, on top of the same
/// origin/destination fields and `Itinerary` action as
/// compute-navigation. See `docs/features/custom-navigation-trace.md`.
struct CustomNavigationTracePanel: View {
    @ObservedObject var model: CustomNavigationTraceModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            OriginDestinationFields(origin: $model.origin, destination: $model.destination)

            Button("Itinerary") {
                model.showItinerary()
            }
            .frame(maxWidth: .infinity)
            .buttonStyle(.borderedProminent)
            .disabled(model.route == nil)

            Divider()

            Text("Trace color")
                .font(.footnote)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                ForEach(NavigationTracePreset.allCases) { preset in
                    swatch(for: preset)
                }
            }
        }
        .padding()
    }

    private func swatch(for preset: NavigationTracePreset) -> some View {
        Button {
            model.select(preset)
        } label: {
            Circle()
                .fill(preset.swatchColor)
                .frame(width: 36, height: 36)
                .overlay(
                    Circle().stroke(Color.primary, lineWidth: preset == model.tracePreset ? 3 : 0)
                )
        }
        .accessibilityLabel(Text(preset.label))
    }
}
