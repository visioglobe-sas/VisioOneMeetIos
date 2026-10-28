import SwiftUI

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
