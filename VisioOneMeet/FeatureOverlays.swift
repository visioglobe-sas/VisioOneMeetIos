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

/// Lets the user switch floor (and building, when the venue has more than
/// one) by tapping a native list, via `view.goToFloor()`/`view.goToBuilding()`.
/// See docs/features/floor-selector.md — this is deliberately separate from
/// the SDK's own default floor-selector widget, which keeps working
/// alongside this one.
struct FloorSelectorOverlay: View {
    @ObservedObject var bridge: VisioOneBridge

    private var buildings: [VenueBuilding] { bridge.floorSelection.buildings }

    private var currentBuilding: VenueBuilding? {
        buildings.first { $0.id == bridge.floorSelection.currentBuildingId } ?? buildings.first
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 20) {
                if buildings.isEmpty {
                    Text("No building/floor data yet")
                        .foregroundStyle(.secondary)
                } else {
                    if buildings.count > 1 {
                        buildingSection
                    }
                    floorSection
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding()
        }
    }

    private var buildingSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Building")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            ForEach(buildings) { building in
                selectionButton(
                    label: building.label,
                    isSelected: building.id == bridge.floorSelection.currentBuildingId
                ) {
                    bridge.goToBuilding(building.id)
                }
            }
        }
    }

    private var floorSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Floor")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            // Sorted top-to-bottom already by the JS side (by altitude).
            ForEach(currentBuilding?.floors ?? []) { floor in
                selectionButton(
                    label: floor.label,
                    isSelected: floor.id == bridge.floorSelection.currentFloorId
                ) {
                    bridge.goToFloor(floor.id)
                }
            }
        }
    }

    private func selectionButton(label: String, isSelected: Bool, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            HStack {
                Text(label)
                Spacer()
                if isSelected {
                    Image(systemName: "checkmark")
                }
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 8)
            .padding(.horizontal, 12)
            .foregroundStyle(isSelected ? Color.white : Color.accentColor)
            .background(isSelected ? Color.accentColor : Color.clear, in: RoundedRectangle(cornerRadius: 8))
            .overlay(
                RoundedRectangle(cornerRadius: 8)
                    .strokeBorder(Color.accentColor, lineWidth: isSelected ? 0 : 1)
            )
        }
        .buttonStyle(.plain)
    }
}

/// Lets the user type two Place IDs and compute/display a route between
/// them via `venue.computeNavigation()` + `view.setCurrentNavigationTrace()`.
/// See docs/features/compute-navigation.md. `isAccessible` is hardcoded to
/// `false` here — same choice as the React Native sibling — to keep this a
/// minimal demonstration of the bridge call rather than a full accessibility
/// toggle UI.
struct ComputeNavigationOverlay: View {
    @ObservedObject var bridge: VisioOneBridge
    @State private var originPlaceId = ""
    @State private var destinationPlaceId = ""

    private var canComputeNavigation: Bool {
        !originPlaceId.trimmingCharacters(in: .whitespaces).isEmpty
            && !destinationPlaceId.trimmingCharacters(in: .whitespaces).isEmpty
    }

    var body: some View {
        VStack(spacing: 12) {
            TextField("From (Place ID)", text: $originPlaceId)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            TextField("To (Place ID)", text: $destinationPlaceId)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            Button("Itinerary") {
                computeNavigation()
            }
            .frame(maxWidth: .infinity)
            .buttonStyle(.borderedProminent)
            .disabled(!canComputeNavigation)
        }
        .padding()
    }

    private func computeNavigation() {
        let origin = originPlaceId.trimmingCharacters(in: .whitespaces)
        let destination = destinationPlaceId.trimmingCharacters(in: .whitespaces)
        guard !origin.isEmpty, !destination.isEmpty else { return }
        bridge.computeNavigation(origin: origin, destination: destination, isAccessible: false)
    }
}

/// The 5 UI parts the SDK's `view.setUIPartVisible()` can individually
/// show/hide. Raw values match the JS SDK's `UIPart` type exactly
/// (case-sensitive) — see docs/features/ui-part-visibility.md.
enum MapUIPart: String, CaseIterable, Identifiable {
    case floorSelector
    case navigation
    case poiDetails
    case search
    case userTracking

    var id: String { rawValue }

    var title: LocalizedStringResource {
        switch self {
        case .floorSelector:
            return "feature.ui_part_visibility.part.floor_selector"
        case .navigation:
            return "feature.ui_part_visibility.part.navigation"
        case .poiDetails:
            return "feature.ui_part_visibility.part.poi_details"
        case .search:
            return "feature.ui_part_visibility.part.search"
        case .userTracking:
            return "feature.ui_part_visibility.part.user_tracking"
        }
    }
}

/// Lets the user show/hide each of the SDK's own default UI overlays via
/// `view.setUIPartVisible()`. All 5 toggles default to on/visible, matching
/// the SDK's own default — nothing is hidden until the user flips a switch.
/// See docs/features/ui-part-visibility.md.
struct UIPartVisibilityOverlay: View {
    @ObservedObject var bridge: VisioOneBridge
    @State private var visibility: [MapUIPart: Bool] = Dictionary(
        uniqueKeysWithValues: MapUIPart.allCases.map { ($0, true) }
    )

    var body: some View {
        List(MapUIPart.allCases) { part in
            Toggle(isOn: binding(for: part)) {
                Text(part.title)
            }
        }
        .listStyle(.plain)
    }

    private func binding(for part: MapUIPart) -> Binding<Bool> {
        Binding(
            get: { visibility[part, default: true] },
            set: { newValue in
                visibility[part] = newValue
                bridge.setUIPartVisible(part.rawValue, isVisible: newValue)
            }
        )
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
