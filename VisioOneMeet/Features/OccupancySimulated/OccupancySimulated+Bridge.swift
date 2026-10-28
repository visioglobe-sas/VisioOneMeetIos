import Foundation

extension VisioOneBridge {
    /// Updates a POI's surface color to reflect an occupancy status
    /// (`color: nil` resets the surface to its normal appearance). See
    /// `docs/features/occupancy-simulated.md`.
    func updateOccupancy(poiId: String, color: String?) {
        call("updateOccupancy", args: [poiId, color])
    }
}
