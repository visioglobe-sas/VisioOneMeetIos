import Foundation

/// User-facing message for a custom-text-label / html-overlay-marker call
/// (`isBadge`), `nil` on success.
func placedObjectErrorMessage(_ result: BridgeResult, isBadge: Bool) -> String? {
    switch result {
    case .success:
        return nil
    case .textRequired:
        return String(localized: "Text is required")
    case .poiNotFound:
        return String(localized: "POI not found")
    case .noPosition:
        return String(localized: "This POI has no position")
    case .nothingPlaced:
        return isBadge ? String(localized: "No badge placed") : String(localized: "No label placed")
    case .sdkError(let message), .bridgeError(let message):
        return isBadge
            ? String(localized: "Could not place the badge: \(message)")
            : String(localized: "Could not place the label: \(message)")
    case .noSurface, .duplicate:
        return isBadge
            ? String(localized: "Could not place the badge: \(String(describing: result))")
            : String(localized: "Could not place the label: \(String(describing: result))")
    }
}
