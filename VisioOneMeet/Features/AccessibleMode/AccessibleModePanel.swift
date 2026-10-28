import SwiftUI

/// Lets the user type two Place IDs and compute/display a route between
/// them like compute-navigation, plus an "Accessible route" toggle
/// forwarded as `venue.computeNavigation()`'s `isAccessible` option. It is
/// the opposite direction from navigation-exclude-modalities' "Avoid
/// elevator": instead of excluding `'lift'` to force a stairway detour, it
/// applies the venue's own accessible-route exclusions (stairs-only segments
/// here) to force a lift/ramp route. See `docs/features/accessible-mode.md`.
struct AccessibleModePanel: View {
    @ObservedObject var model: AccessibleModeModel

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

            Toggle("Accessible route", isOn: $model.isAccessible)
        }
        .padding()
    }
}
