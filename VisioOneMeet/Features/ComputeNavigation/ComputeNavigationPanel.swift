import SwiftUI

/// Lets the user type two Place IDs and compute/display a route between
/// them via `venue.computeNavigation()` + `view.setCurrentNavigationTrace()`.
/// See docs/features/compute-navigation.md.
struct ComputeNavigationPanel: View {
    @ObservedObject var model: ComputeNavigationModel

    var body: some View {
        VStack(spacing: 12) {
            OriginDestinationFields(origin: $model.origin, destination: $model.destination)

            Button("Itinerary") {
                model.showItinerary()
            }
            .frame(maxWidth: .infinity)
            .buttonStyle(.borderedProminent)
            .disabled(model.route == nil)
        }
        .padding()
    }
}
