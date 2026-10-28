import SwiftUI

/// One label at a time. The placed state and the selected style live here,
/// so they survive the panel being dismissed and reopened. See
/// docs/features/custom-text-label.md.
@MainActor
final class CustomTextLabelModel: ObservableObject, FeatureModel {
    static let rotations = [0, 45, 90]

    @Published var anchorPoiId = DemoMap.anchorPoiId
    @Published var text = DemoMap.textLabelText
    /// Anchor POI id the label is currently placed on, `nil` when none is
    /// placed, plus that label's current text.
    @Published private(set) var placedAnchorId: String?
    @Published private(set) var placedText: String?
    /// Style applied on the next place and live to an already placed label.
    @Published private(set) var color: TextLabelColor = .red
    @Published private(set) var size: TextLabelSize = .medium
    @Published private(set) var rotation = 0

    let bridge: VisioOneBridge

    init(bridge: VisioOneBridge) {
        self.bridge = bridge
        bridge.onReload { [weak self] in self?.clearPlaced() }
    }

    func makePanel() -> AnyView { AnyView(CustomTextLabelPanel(model: self)) }

    var trimmedAnchorPoiId: String { anchorPoiId.trimmingCharacters(in: .whitespaces) }

    var hasLabel: Bool { placedAnchorId != nil }

    func place(anchorId: String) async -> BridgeResult {
        let text = text
        let result = await bridge.placeTextLabel(anchorId: anchorId, text: text, color: color, size: size, rotation: rotation)
        switch result {
        case .success:
            placedAnchorId = anchorId
            placedText = text
        case .sdkError:
            // Validation passed and the previous label was already removed,
            // but venue.createLabel itself threw: nothing is placed anymore.
            clearPlaced()
        default:
            // Validation failed before anything was touched (the existing
            // label, if any, is still placed and usable), or the bridge call
            // itself failed (map state unknown): keep the native state.
            break
        }
        return result
    }

    /// Changes the placed label's text via `venue.updateLabel(label, { text })`.
    func updateText() async -> BridgeResult {
        guard bridge.webView != nil else { return .bridgeError("Map not ready") }
        guard hasLabel else { return .nothingPlaced }
        let text = text
        let result = await bridge.updateTextLabel(["text": text])
        if result == .success {
            placedText = text
        }
        return result
    }

    func setColor(_ newValue: TextLabelColor) {
        color = newValue
        guard bridge.webView != nil, hasLabel else { return }
        Task { _ = await bridge.updateTextLabel(["color": newValue.rawValue]) }
    }

    /// Always width and height together, since `width` alone also resets
    /// `height` to `width`.
    func setSize(_ newValue: TextLabelSize) {
        size = newValue
        guard bridge.webView != nil, hasLabel else { return }
        Task { _ = await bridge.updateTextLabel(["width": newValue.width, "height": newValue.height]) }
    }

    func setRotation(_ newValue: Int) {
        rotation = newValue
        guard bridge.webView != nil, hasLabel else { return }
        Task {
            // The label was removed, then recreating it threw: nothing is
            // placed anymore. (A bridge failure leaves the state as is.)
            if case .sdkError = await bridge.setTextLabelRotation(newValue) {
                clearPlaced()
            }
        }
    }

    /// Cleared optimistically. No-op if nothing is placed.
    func remove() {
        guard bridge.webView != nil, hasLabel else { return }
        clearPlaced()
        bridge.removeTextLabel()
    }

    private func clearPlaced() {
        placedAnchorId = nil
        placedText = nil
    }
}
