import Foundation

/// Result of `loadCustomData`, distinguishing a POI that doesn't exist from
/// one that exists but has no business CustomData (an empty dictionary) --
/// both are normal, non-error states (see `docs/features/custom-data.md`).
enum CustomDataLookup: Equatable {
    case poiNotFound
    case data([String: String])
}

extension VisioOneBridge {
    /// Refreshes the venue's CustomData cache via `venue.refreshCustomData()`,
    /// then reads the given POI's data via `venue.getPOICustomData()` in the
    /// same JS call (see `docs/features/custom-data.md`). The JS side awaits a
    /// network round trip, which `callForResult` waits for.
    ///
    /// Returns `nil` on a bridge/JS failure (logged, not surfaced further);
    /// `.poiNotFound` when `poiId` doesn't resolve to a POI in the loaded
    /// venue; `.data(_)` otherwise, where the dictionary is `{}` (never
    /// `nil`) when the POI has no CustomData.
    func loadCustomData(_ poiId: String) async -> CustomDataLookup? {
        guard case .success(let value) = await callForResult("loadCustomData", args: [poiId]),
              let payload = value as? [String: Any],
              let found = payload["found"] as? Bool else { return nil }
        guard found else { return .poiNotFound }
        return .data(payload["data"] as? [String: String] ?? [:])
    }
}
