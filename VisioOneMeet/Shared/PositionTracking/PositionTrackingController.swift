import Foundation

/// A WGS84 point, as returned by `resolvePoiPosition` for a POI's display
/// position (see `docs/features/simulated-position.md`).
struct GeoPosition: Equatable {
    let latitude: Double
    let longitude: Double
}

// Stand-in for a real indoor-positioning feed: interpolates a position
// between two POIs on a timer and feeds it to `injectTrackedPosition`, same
// way `occupancy-simulated` stands in for a real occupancy sensor. See
// docs/features/simulated-position.md.
private let simulatedPositionIntervalNanoseconds: UInt64 = 150_000_000
private let simulatedPositionStepFraction: Double = 0.02 // ~50 ticks (7.5s) per leg

/// Drives the origin/destination-POI ping-pong loop shared by the four
/// tracking screens (simulated-position, camera-lock-on-position,
/// geofencing, accuracy-circle-style): resolve two POI ids once, then
/// interpolate between them on a repeating timer. The SDK calls are
/// simulated-position's (`SimulatedPosition+Bridge.swift`). See
/// `docs/features/simulated-position.md`.
///
/// Owned by the feature model of the screen, not by the control sheet: the
/// panels only observe it. Dismissing the sheet therefore leaves the
/// simulation running (the user can pan/zoom the map while the position
/// keeps moving), reopening it shows the same running controller (Stop
/// button, filled fields), and there is only ever one loop per screen.
/// Leaving the screen (or reloading the map) calls `stopIfRunning()`.
@MainActor
final class PositionTrackingController: ObservableObject {
    @Published var originPlaceId: String
    @Published var destinationPlaceId: String
    @Published var precisionCircleRadius: Double
    @Published private(set) var isSimulating = false
    @Published var errorMessage: String?

    private let bridge: VisioOneBridge
    private var simulationTask: Task<Void, Never>?

    /// Optional per-tick hook, invoked with the same interpolated position
    /// just sent to `injectTrackedPosition`. Used by geofencing
    /// (`GeofencingModel`) to run its point-in-polygon check on every tick
    /// without a second timer. See `docs/features/geofencing.md`.
    var onTick: ((GeoPosition) -> Void)?

    /// Optional hook invoked once per Start, after both POIs resolved and
    /// right before the first `injectTrackedPosition`. Used by
    /// accuracy-circle-style: the SDK resets the position tracker's
    /// color/opacity whenever tracking stops, so the selected style has to
    /// be re-sent before each new run. See
    /// `docs/features/accuracy-circle-style.md`.
    var onWillStartTracking: (() -> Void)?

    /// The tracking screens pre-fill the demo origin/destination POIs.
    init(
        bridge: VisioOneBridge,
        originPlaceId: String = DemoMap.trackingFrom,
        destinationPlaceId: String = DemoMap.trackingTo,
        precisionCircleRadius: Double = 5
    ) {
        self.bridge = bridge
        self.originPlaceId = originPlaceId
        self.destinationPlaceId = destinationPlaceId
        self.precisionCircleRadius = precisionCircleRadius
    }

    var canStart: Bool {
        !originPlaceId.trimmingCharacters(in: .whitespaces).isEmpty
            && !destinationPlaceId.trimmingCharacters(in: .whitespaces).isEmpty
    }

    func toggle() {
        if isSimulating {
            stop()
        } else {
            start()
        }
    }

    func start() {
        // One loop per controller: a second Start while one is already
        // running (or still resolving its POIs) would interleave two
        // ping-pong loops on the same tracked position.
        guard simulationTask == nil else { return }
        let origin = originPlaceId.trimmingCharacters(in: .whitespaces)
        let destination = destinationPlaceId.trimmingCharacters(in: .whitespaces)
        guard !origin.isEmpty, !destination.isEmpty else { return }

        errorMessage = nil
        isSimulating = true

        simulationTask = Task {
            async let originPosition = bridge.resolvePoiPosition(origin)
            async let destinationPosition = bridge.resolvePoiPosition(destination)

            let resolvedOrigin = await originPosition
            let resolvedDestination = await destinationPosition
            guard !Task.isCancelled else { return }
            guard let originPos = resolvedOrigin, let destPos = resolvedDestination else {
                errorMessage = String(localized: "Origin or destination POI not found")
                isSimulating = false
                simulationTask = nil
                return
            }
            onWillStartTracking?()

            var progress = 0.0
            var direction = 1.0
            while !Task.isCancelled {
                let currentPosition = GeoPosition(
                    latitude: originPos.latitude + (destPos.latitude - originPos.latitude) * progress,
                    longitude: originPos.longitude + (destPos.longitude - originPos.longitude) * progress
                )
                bridge.injectTrackedPosition(
                    latitude: currentPosition.latitude,
                    longitude: currentPosition.longitude,
                    precisionCircleRadius: precisionCircleRadius
                )
                onTick?(currentPosition)

                progress += direction * simulatedPositionStepFraction
                if progress >= 1 {
                    progress = 1
                    direction = -1
                } else if progress <= 0 {
                    progress = 0
                    direction = 1
                }

                try? await Task.sleep(nanoseconds: simulatedPositionIntervalNanoseconds)
            }
        }
    }

    func stop() {
        simulationTask?.cancel()
        simulationTask = nil
        isSimulating = false
        bridge.stopTrackedPosition()
    }

    /// Called when the feature screen goes away (back to the menu): ends the
    /// loop so nothing keeps injecting into a map that's being torn down.
    func stopIfRunning() {
        guard isSimulating else { return }
        stop()
    }
}
