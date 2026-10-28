import SwiftUI

/// Controls for the camera tour. The loop itself lives in the page and its
/// state on the model, so this panel can be closed (to watch the map) and
/// reopened at any time. See `docs/features/camera-showcase-carousel.md`.
struct CameraShowcaseCarouselPanel: View {
    @ObservedObject var model: CameraShowcaseCarouselModel

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            if model.status == .stopped {
                Button {
                    model.bridge.startCarousel()
                } label: {
                    Text("feature.camera_showcase_carousel.start")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            } else {
                Button(role: .destructive) {
                    model.bridge.stopCarousel()
                } label: {
                    Text("feature.camera_showcase_carousel.stop")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.borderedProminent)
            }

            statusText
                .font(.subheadline)

            Text("feature.camera_showcase_carousel.hint")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
        .padding()
    }

    @ViewBuilder
    private var statusText: some View {
        switch model.status {
        case .stopped:
            Text("feature.camera_showcase_carousel.status.stopped")
        case .paused:
            Text("feature.camera_showcase_carousel.status.paused")
        case let .running(stop, total, poiId):
            Text("feature.camera_showcase_carousel.status.running \(stop) \(total) \(poiId)")
        }
    }
}
