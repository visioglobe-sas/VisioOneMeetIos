import SwiftUI

// Stand-in for a real occupancy sensor feed: cycles a POI's surface through
// these colors on a timer. See docs/features/occupancy-simulated.md.
private let occupancyColors = ["#2ECC71", "#F1C40F", "#E74C3C"]
private let occupancyIntervalNanoseconds: UInt64 = 2_500_000_000

/// Drives the occupancy-simulated loop. Owned by the feature screen, not by
/// the panel (same model as `PositionTrackingController`): closing the panel
/// leaves the simulation running, reopening it shows the running state (Stop
/// button, same POI id), there is only ever one loop per screen, and leaving
/// the screen stops it.
@MainActor
final class OccupancySimulatedModel: ObservableObject, FeatureModel {
    @Published var placeId = DemoMap.occupancyPlaceId
    @Published private(set) var isSimulating = false

    let bridge: VisioOneBridge
    private var simulationTask: Task<Void, Never>?
    private var simulatedPlaceId: String?

    init(bridge: VisioOneBridge) {
        self.bridge = bridge
        bridge.onReload { [weak self] in self?.stopIfRunning() }
    }

    func makePanel() -> AnyView { AnyView(OccupancySimulatedPanel(model: self)) }

    func screenDidDisappear() {
        stopIfRunning()
    }

    var canStart: Bool { !placeId.trimmingCharacters(in: .whitespaces).isEmpty }

    func toggle() {
        if isSimulating {
            stop()
        } else {
            start()
        }
    }

    func start() {
        guard simulationTask == nil else { return }
        let target = placeId.trimmingCharacters(in: .whitespaces)
        guard !target.isEmpty else { return }

        isSimulating = true
        simulatedPlaceId = target
        simulationTask = Task { [bridge] in
            var colorIndex = 0
            while !Task.isCancelled {
                bridge.updateOccupancy(poiId: target, color: occupancyColors[colorIndex])
                colorIndex = (colorIndex + 1) % occupancyColors.count
                try? await Task.sleep(nanoseconds: occupancyIntervalNanoseconds)
            }
        }
    }

    func stop() {
        simulationTask?.cancel()
        simulationTask = nil
        isSimulating = false
        // Reset the surface rather than leaving it stuck on the last color.
        if let simulatedPlaceId {
            bridge.updateOccupancy(poiId: simulatedPlaceId, color: nil)
        }
        simulatedPlaceId = nil
    }

    /// Called when the feature screen goes away (back to the menu).
    func stopIfRunning() {
        guard isSimulating else { return }
        stop()
    }
}
