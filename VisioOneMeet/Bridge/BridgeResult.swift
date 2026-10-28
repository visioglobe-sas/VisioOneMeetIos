import Foundation

/// Outcome of a JS bridge function that reports it as a `{ status, message? }`
/// object rather than throwing (see `VisioOneBridge.callForStatus`). Every
/// expected outcome (unknown POI, empty text...) is a normal value; only a
/// real bridge failure is `.bridgeError`.
enum BridgeResult: Equatable {
    /// `'placed'`, `'updated'`, `'created'`, `'applied'` or `'ok'`.
    case success
    /// `'poiNotFound'`, `'anchorNotFound'` or `'notFound'`: no POI with that id.
    case poiNotFound
    /// `'noPosition'`: the POI has nothing to read a position from.
    case noPosition
    /// `'noSurface'`: the POI has no usable surface geometry.
    case noSurface
    /// `'textRequired'`: the text is empty after trimming.
    case textRequired
    /// `'noLabel'` / `'noBadge'`: nothing is placed to update.
    case nothingPlaced
    /// `'duplicate'`: the id is already used in the venue.
    case duplicate
    /// The SDK call itself threw (`{ status: 'error', message }`).
    case sdkError(String)
    /// The bridge call failed (WebKit error, map not ready, unexpected
    /// response): what is on the map is unknown.
    case bridgeError(String)

    init(payload: Any?) {
        guard let payload = payload as? [String: Any], let status = payload["status"] as? String else {
            self = .bridgeError("Unexpected bridge response")
            return
        }
        switch status {
        case "placed", "updated", "created", "applied", "ok":
            self = .success
        case "poiNotFound", "anchorNotFound", "notFound":
            self = .poiNotFound
        case "noPosition":
            self = .noPosition
        case "noSurface":
            self = .noSurface
        case "textRequired":
            self = .textRequired
        case "noLabel", "noBadge":
            self = .nothingPlaced
        case "duplicate":
            self = .duplicate
        default:
            self = .sdkError(payload["message"] as? String ?? status)
        }
    }
}
