import Foundation

extension VisioOneBridge {
    /// Starts the automatic camera tour (`view.goToFloor` + `view.goToPOI`
    /// on each stop of `stopIds`, looped in
    /// `features/camera-showcase-carousel.js`). See
    /// `docs/features/camera-showcase-carousel.md`.
    func startCarousel(stopIds: [String] = DemoMap.carouselStopIds) {
        call("startCarousel", args: [stopIds])
    }

    /// Stops the camera tour where the camera currently is. Also called when
    /// leaving the screen.
    func stopCarousel() {
        call("stopCarousel")
    }
}
