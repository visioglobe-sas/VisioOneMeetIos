import SwiftUI

/// Lets the user type two Place IDs and compute/display a route between
/// them like compute-navigation, but additionally exposes an "Avoid
/// elevator" toggle that excludes the `'lift'` segment attribute via
/// `VisioOneBridge.computeNavigationExcludingModalities`. See
/// `docs/features/navigation-exclude-modalities.md`.
struct NavigationExcludeModalitiesPanel: View {
    @ObservedObject var model: NavigationExcludeModalitiesModel

    var body: some View {
        VStack(spacing: 12) {
            OriginDestinationFields(origin: $model.origin, destination: $model.destination)

            HStack {
                Button("Itinerary") {
                    model.showItinerary()
                }
                .buttonStyle(.borderedProminent)
                .disabled(model.route == nil)

                Button("Clear") {
                    model.clear()
                }
            }
            .frame(maxWidth: .infinity)

            Toggle("Avoid elevator", isOn: $model.avoidElevator)
        }
        .padding()
    }
}
