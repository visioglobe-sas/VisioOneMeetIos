import Foundation

/// Color choices offered for the custom text label. Raw values are the hex
/// strings passed as-is to `venue.createLabel`/`venue.updateLabel`'s
/// `color` (hex, `rgb()` or `hsl()` only -- anything else throws). See
/// `docs/features/custom-text-label.md`.
enum TextLabelColor: String, CaseIterable, Identifiable {
    case red = "#E53935"
    case green = "#43A047"
    case blue = "#1E88E5"
    case dark = "#212121"

    var id: String { rawValue }
}

/// Size presets for the custom text label, in meters. Width and height are
/// always sent together: the SDK defaults `height` to `width` on create, and
/// `updateLabel(label, { width })` alone also resets `height` to `width`.
enum TextLabelSize: String, CaseIterable, Identifiable {
    case small
    case medium
    case large

    var id: String { rawValue }

    var width: Double {
        switch self {
        case .small: return 10
        case .medium: return 16
        case .large: return 22
        }
    }

    var height: Double {
        switch self {
        case .small: return 2
        case .medium: return 3
        case .large: return 4
        }
    }
}

extension VisioOneBridge {
    /// Places free text on the map via `venue.createLabel()`, owned by the
    /// anchor POI `anchorId` and positioned ~4 m off that POI's display
    /// position, with this color/size/rotation. The JS side validates
    /// everything (text, anchor POI, anchor position) before touching an
    /// already placed label: a failed validation leaves it in place and still
    /// usable; only once all checks pass is it replaced, so at most one
    /// exists. Every outcome comes back as a normal value.
    func placeTextLabel(anchorId: String, text: String, color: TextLabelColor, size: TextLabelSize, rotation: Int) async -> BridgeResult {
        await callForStatus("placeTextLabel", args: [anchorId, text, color.rawValue, size.width, size.height, rotation])
    }

    /// Restyles the placed label via `venue.updateLabel(label, options)`,
    /// `options` being any subset of `text`, `color`, `width` + `height`.
    func updateTextLabel(_ options: [String: Any]) async -> BridgeResult {
        await callForStatus("updateTextLabel", args: [options])
    }

    /// Recreates the placed label with another rotation: `rotation` is only
    /// accepted by `venue.createLabel`, not by `venue.updateLabel`.
    func setTextLabelRotation(_ rotation: Int) async -> BridgeResult {
        await callForStatus("setTextLabelRotation", args: [rotation])
    }

    /// Removes the placed label via `venue.removeLabel()`; the anchor POI
    /// and its own map label are untouched.
    func removeTextLabel() {
        call("removeTextLabel")
    }
}
