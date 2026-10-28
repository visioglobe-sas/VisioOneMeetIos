import SwiftUI

/// One badge at a time. The placed state lives here, so it survives the
/// panel being dismissed and reopened (the badge can only be tapped with the
/// panel closed). See docs/features/html-overlay-marker.md.
@MainActor
final class HtmlOverlayMarkerModel: ObservableObject, FeatureModel {
    @Published var anchorPoiId = DemoMap.anchorPoiId
    @Published var text = DemoMap.htmlBadgeText
    /// Anchor POI id the badge is currently placed on, `nil` when none is
    /// placed, plus that badge's current text, whether it's currently shown,
    /// and how many times it was tapped since the last successful place
    /// (pushed by the JS side's `htmlBadgeTapped` message).
    @Published private(set) var placedAnchorId: String?
    @Published private(set) var placedText: String?
    @Published private(set) var isBadgeVisible = true
    @Published private(set) var tapCount = 0

    let bridge: VisioOneBridge

    init(bridge: VisioOneBridge) {
        self.bridge = bridge
        // Sent by the badge element's own click listener in
        // features/html-overlay-marker.js.
        bridge.onMessage("htmlBadgeTapped") { [weak self] _ in
            self?.tapCount += 1
        }
        bridge.onReload { [weak self] in self?.clearPlaced() }
    }

    func makePanel() -> AnyView { AnyView(HtmlOverlayMarkerPanel(model: self)) }

    var trimmedAnchorPoiId: String { anchorPoiId.trimmingCharacters(in: .whitespaces) }

    var hasBadge: Bool { placedAnchorId != nil }

    /// On success the badge starts visible and the tap counter resets to 0.
    func place(anchorId: String) async -> BridgeResult {
        let text = text
        let result = await bridge.placeHtmlBadge(anchorId: anchorId, text: text)
        switch result {
        case .success:
            placedAnchorId = anchorId
            placedText = text
            isBadgeVisible = true
            tapCount = 0
        case .sdkError:
            // Validation passed and the previous badge was already removed,
            // but venue.createMarker itself threw: nothing is placed anymore.
            clearPlaced()
        default:
            // Validation failed before anything was touched, or the bridge
            // call itself failed (map state unknown): keep the native state.
            break
        }
        return result
    }

    func updateText() async -> BridgeResult {
        guard bridge.webView != nil else { return .bridgeError("Map not ready") }
        guard hasBadge else { return .nothingPlaced }
        let text = text
        let result = await bridge.updateHtmlBadgeText(text)
        if result == .success {
            placedText = text
        }
        return result
    }

    func toggleVisibility() async {
        guard bridge.webView != nil, hasBadge else { return }
        let isVisible = !isBadgeVisible
        if await bridge.setHtmlBadgeVisible(isVisible) == .success {
            isBadgeVisible = isVisible
        }
    }

    /// Cleared optimistically. No-op if nothing is placed.
    func remove() {
        guard bridge.webView != nil, hasBadge else { return }
        clearPlaced()
        bridge.removeHtmlBadge()
    }

    private func clearPlaced() {
        placedAnchorId = nil
        placedText = nil
        isBadgeVisible = true
    }
}
