import SwiftUI

struct ResetViewOverlay: View {
    @ObservedObject var bridge: VisioOneBridge

    var body: some View {
        Button {
            bridge.goToGlobal()
        } label: {
            Text(Feature.resetView.title)
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.borderedProminent)
        .padding()
    }
}

// Stand-in for a real occupancy sensor feed: cycles a POI's surface through
// these colors on a timer. See docs/features/occupancy-simulated.md.
private let occupancyColors = ["#2ECC71", "#F1C40F", "#E74C3C"]
private let occupancyIntervalNanoseconds: UInt64 = 2_500_000_000

struct OccupancyOverlay: View {
    @ObservedObject var bridge: VisioOneBridge
    @State private var placeId = ""
    @State private var simulatingOccupancy = false
    @State private var occupancySimulationTask: Task<Void, Never>?

    var body: some View {
        HStack {
            TextField("Place ID", text: $placeId)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()

            Button(simulatingOccupancy ? "Stop occupancy simulation" : "Simulate occupancy") {
                toggleOccupancySimulation()
            }
        }
        .padding()
    }

    private func toggleOccupancySimulation() {
        if simulatingOccupancy {
            stopOccupancySimulation()
        } else {
            startOccupancySimulation()
        }
    }

    private func startOccupancySimulation() {
        let targetPlaceId = placeId.trimmingCharacters(in: .whitespaces)
        guard !targetPlaceId.isEmpty else { return }

        simulatingOccupancy = true
        occupancySimulationTask = Task {
            var colorIndex = 0
            bridge.updateOccupancy(planId: targetPlaceId, color: occupancyColors[colorIndex])

            while !Task.isCancelled {
                try? await Task.sleep(nanoseconds: occupancyIntervalNanoseconds)
                guard !Task.isCancelled else { break }
                colorIndex = (colorIndex + 1) % occupancyColors.count
                bridge.updateOccupancy(planId: targetPlaceId, color: occupancyColors[colorIndex])
            }

            // Reset the surface rather than leaving it stuck on the last simulated color.
            bridge.updateOccupancy(planId: targetPlaceId, color: nil)
        }
    }

    private func stopOccupancySimulation() {
        occupancySimulationTask?.cancel()
        occupancySimulationTask = nil
        simulatingOccupancy = false
    }
}

/// Lets the user type a Place ID and center the camera on it via
/// `view.goToPOI()`. See docs/features/goto-poi.md.
struct GoToPoiOverlay: View {
    @ObservedObject var bridge: VisioOneBridge
    @State private var placeId = ""

    var body: some View {
        HStack {
            TextField("Place ID", text: $placeId)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            Button("Go") {
                goToPlace()
            }
            .disabled(placeId.trimmingCharacters(in: .whitespaces).isEmpty)

            Button("Clear") {
                bridge.clearPOI()
            }
        }
        .padding()
    }

    private func goToPlace() {
        let targetPlaceId = placeId.trimmingCharacters(in: .whitespaces)
        guard !targetPlaceId.isEmpty else { return }
        bridge.goToPOI(targetPlaceId)
    }
}

/// Content of the panel shown when a POI is tapped on the map. Unlike the
/// other overlays, this one is never opened by a FAB — `FeatureMapView`
/// presents it automatically when `bridge.tappedPOI` goes non-nil, reacting
/// to the SDK's `poiclick` event. See docs/features/poi-click.md.
struct PoiClickOverlay: View {
    @ObservedObject var bridge: VisioOneBridge

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Tapped POI")
                .font(.headline)

            if let poi = bridge.tappedPOI {
                VStack(alignment: .leading, spacing: 4) {
                    Text(poi.name ?? "(no name)")
                        .font(.title3)
                        .fontWeight(.semibold)
                    Text("ID: \(poi.id)")
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
            } else {
                Text("No POI selected")
                    .foregroundStyle(.secondary)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }
}
