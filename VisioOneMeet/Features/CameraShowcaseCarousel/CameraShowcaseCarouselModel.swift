import SwiftUI

/// State of the camera tour, mirrored from the page (which owns the loop)
/// via the `carouselStateChanged` message. See
/// `docs/features/camera-showcase-carousel.md`.
enum CarouselStatus: Equatable {
    case stopped
    /// `stop` is 1-based.
    case running(stop: Int, total: Int, poiId: String)
    case paused
}

@MainActor
final class CameraShowcaseCarouselModel: ObservableObject, FeatureModel {
    /// Pushed by the JS side whenever it changes -- including changes native
    /// didn't ask for (a touch on the map pausing it, the idle timer resuming
    /// it), so the panel always shows the real state.
    @Published private(set) var status: CarouselStatus = .stopped

    let bridge: VisioOneBridge

    init(bridge: VisioOneBridge) {
        self.bridge = bridge
        bridge.onMessage("carouselStateChanged") { [weak self] payload in
            guard let payload = payload as? [String: Any],
                  let state = payload["state"] as? String else { return }
            switch state {
            case "running":
                self?.status = .running(
                    stop: payload["stop"] as? Int ?? 1,
                    total: payload["total"] as? Int ?? 1,
                    poiId: payload["poiId"] as? String ?? ""
                )
            case "paused":
                self?.status = .paused
            default:
                self?.status = .stopped
            }
        }
        bridge.onReload { [weak self] in self?.status = .stopped }
    }

    func makePanel() -> AnyView { AnyView(CameraShowcaseCarouselPanel(model: self)) }

    /// The loop lives in the page: stop it explicitly rather than relying on
    /// the WKWebView teardown.
    func screenDidDisappear() {
        bridge.stopCarousel()
    }
}
