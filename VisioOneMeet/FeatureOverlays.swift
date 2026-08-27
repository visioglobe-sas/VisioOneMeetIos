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

/// The native building/floor list itself, factored out of
/// `FloorSelectorOverlay` so `native-ui-replacement`'s
/// `NativeUiReplacementOverlay` below can reuse the exact same picker rather
/// than reimplementing it — the whole point of that feature is demonstrating
/// this existing native UI as a drop-in replacement for the SDK's own
/// floor-selector widget, not building a second one. See
/// docs/features/floor-selector.md and docs/features/native-ui-replacement.md.
struct FloorSelectorList: View {
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

/// Lets the user switch floor (and building, when the venue has more than
/// one) by tapping a native list, via `view.goToFloor()`/`view.goToBuilding()`.
/// See docs/features/floor-selector.md — this is deliberately separate from
/// the SDK's own default floor-selector widget, which keeps working
/// alongside this one.
struct FloorSelectorOverlay: View {
    @ObservedObject var bridge: VisioOneBridge

    var body: some View {
        FloorSelectorList(bridge: bridge)
    }
}

/// Demonstrates that the app's own native floor/building picker — reused
/// verbatim via `FloorSelectorList` above, not reimplemented — is a
/// complete, fully-functional replacement for the SDK's own default
/// floor-selector widget, via `view.setUIPartVisible('floorSelector', ...)`.
/// The SDK widget starts hidden (`FeatureMapView` enforces
/// `bridge.setSdkFloorSelectorVisible(false)` once the map turns `.ready`),
/// so only the app's picker is visible/functional by default; the "Show
/// SDK's own floor selector" toggle below reveals the SDK's widget alongside
/// it, both driven by the exact same `currentfloorchanged` event, so a
/// visitor can compare the two live rather than take the replacement on
/// faith. The native picker above stays fully functional regardless of the
/// toggle's state — that's the actual point being demonstrated. See
/// docs/features/native-ui-replacement.md.
struct NativeUiReplacementOverlay: View {
    @ObservedObject var bridge: VisioOneBridge

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            FloorSelectorList(bridge: bridge)

            Divider()

            Toggle(isOn: sdkWidgetVisibleBinding) {
                Text("feature.native_ui_replacement.toggle")
            }
            .padding()
        }
    }

    private var sdkWidgetVisibleBinding: Binding<Bool> {
        Binding(
            get: { bridge.isSdkFloorSelectorVisible },
            set: { bridge.setSdkFloorSelectorVisible($0) }
        )
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

// Stand-in for a real indoor-positioning feed: interpolates a position
// between two POIs on a timer and feeds it to `injectTrackedPosition`, same
// way `occupancy-simulated` stands in for a real occupancy sensor. See
// docs/features/simulated-position.md.
private let simulatedPositionIntervalNanoseconds: UInt64 = 150_000_000
private let simulatedPositionStepFraction: Double = 0.02 // ~50 ticks (7.5s) per leg

/// Drives the origin/destination-POI ping-pong loop shared by
/// `SimulatedPositionOverlay` and `CameraLockOnPositionOverlay` (see
/// `docs/features/simulated-position.md` and
/// `docs/features/camera-lock-on-position.md`) — extracted so the ~60-line
/// loop (resolve two POI ids once, then interpolate between them on a
/// repeating timer) isn't duplicated between the two screens, which only
/// differ in what they show alongside it (the latter adds a camera-lock
/// toggle). Resolution + the loop itself are unchanged from the original
/// `SimulatedPositionOverlay` implementation.
@MainActor
final class PositionTrackingController: ObservableObject {
    @Published var originPlaceId = ""
    @Published var destinationPlaceId = ""
    @Published var precisionCircleRadius: Double = 5
    @Published private(set) var isSimulating = false
    @Published var errorMessage: String?

    private let bridge: VisioOneBridge
    private var simulationTask: Task<Void, Never>?

    init(bridge: VisioOneBridge) {
        self.bridge = bridge
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
        let origin = originPlaceId.trimmingCharacters(in: .whitespaces)
        let destination = destinationPlaceId.trimmingCharacters(in: .whitespaces)
        guard !origin.isEmpty, !destination.isEmpty else { return }

        errorMessage = nil
        isSimulating = true

        simulationTask = Task {
            async let originPosition = bridge.resolvePoiPosition(origin)
            async let destinationPosition = bridge.resolvePoiPosition(destination)

            guard let originPos = await originPosition, let destPos = await destinationPosition else {
                errorMessage = "Origin or destination POI not found"
                isSimulating = false
                return
            }
            guard !Task.isCancelled else { return }

            var progress = 0.0
            var direction = 1.0
            while !Task.isCancelled {
                bridge.injectTrackedPosition(
                    latitude: originPos.latitude + (destPos.latitude - originPos.latitude) * progress,
                    longitude: originPos.longitude + (destPos.longitude - originPos.longitude) * progress,
                    precisionCircleRadius: precisionCircleRadius
                )

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
}

/// The Origin/Destination POI ID fields + accuracy slider + Start/Stop
/// button shared by `SimulatedPositionOverlay` and
/// `CameraLockOnPositionOverlay` — factored out so this ~25-line block of UI
/// isn't duplicated between the two screens; only the controller instance
/// (and, for the camera-lock screen, an extra toggle appended below it in
/// the caller) differs.
struct PositionTrackingControls: View {
    @ObservedObject var controller: PositionTrackingController

    var body: some View {
        Group {
            TextField("Origin POI ID", text: $controller.originPlaceId)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .disabled(controller.isSimulating)

            TextField("Destination POI ID", text: $controller.destinationPlaceId)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .disabled(controller.isSimulating)

            VStack(alignment: .leading, spacing: 4) {
                Text("Accuracy radius: \(Int(controller.precisionCircleRadius)) m")
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                Slider(value: $controller.precisionCircleRadius, in: 1...20, step: 1)
            }

            if let errorMessage = controller.errorMessage {
                Text(errorMessage)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            Button(controller.isSimulating ? "Stop simulated position" : "Simulate position") {
                controller.toggle()
            }
            .frame(maxWidth: .infinity)
            .buttonStyle(.borderedProminent)
            .disabled(!controller.isSimulating && !controller.canStart)
        }
    }
}

/// Lets the user animate a simulated tracked position + accuracy circle
/// back and forth between two POIs via `view.injectTrackedPosition()`. Two
/// Place ID fields resolve to WGS84 positions once at Start (through
/// `VisioOneBridge.resolvePoiPosition`, itself backed by the POIs' own
/// markers/labels/images — see `docs/features/simulated-position.md`), then
/// a repeating Swift-side loop — now `PositionTrackingController` above,
/// same idiom as `OccupancyOverlay` further up — ping-pongs a linear
/// interpolation between them, independent of whether this sheet stays
/// open.
struct SimulatedPositionOverlay: View {
    @StateObject private var controller: PositionTrackingController

    init(bridge: VisioOneBridge) {
        _controller = StateObject(wrappedValue: PositionTrackingController(bridge: bridge))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PositionTrackingControls(controller: controller)
        }
        .padding()
    }
}

/// Lets the user lock the camera onto the same simulated tracked position
/// driven by `PositionTrackingController` above (identical Origin/
/// Destination POI ID + accuracy + Start/Stop UI, via
/// `PositionTrackingControls`), plus a **Recenter camera on position**
/// toggle that calls `view.lockCameraPositionOnTracking` through
/// `VisioOneBridge.setCameraLockOnPosition`. See
/// `docs/features/camera-lock-on-position.md`.
///
/// The toggle is disabled while no simulation is running — locking onto
/// nothing has no visible effect — and is reset off (with the matching
/// `bridge.setCameraLockOnPosition(false)` call) whenever the simulation
/// stops, whether via the Stop button or a "POI not found" error:
/// `onChange(of: controller.isSimulating)` below reacts to both transitions
/// uniformly, since `PositionTrackingController` flips `isSimulating` back
/// to `false` in either case. Leaving the screen entirely tears down the
/// `WKWebView` (see `MapWebView.swift`/CLAUDE.md), which discards the SDK's
/// `view` — and with it `lockCameraPositionOnTracking` — the same way it
/// already discards the tracked position itself, so no separate handling
/// is needed for that third case.
struct CameraLockOnPositionOverlay: View {
    @ObservedObject var bridge: VisioOneBridge
    @StateObject private var controller: PositionTrackingController
    @State private var isCameraLocked = false

    init(bridge: VisioOneBridge) {
        self.bridge = bridge
        _controller = StateObject(wrappedValue: PositionTrackingController(bridge: bridge))
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            PositionTrackingControls(controller: controller)

            Divider()

            Toggle(isOn: cameraLockBinding) {
                Text("Recenter camera on position")
            }
            .disabled(!controller.isSimulating)
        }
        .padding()
        .onChange(of: controller.isSimulating) { simulating in
            guard !simulating, isCameraLocked else { return }
            isCameraLocked = false
            bridge.setCameraLockOnPosition(false)
        }
    }

    private var cameraLockBinding: Binding<Bool> {
        Binding(
            get: { isCameraLocked },
            set: { newValue in
                isCameraLocked = newValue
                bridge.setCameraLockOnPosition(newValue)
            }
        )
    }
}

/// Lets the user type a Place ID and toggle its surface(s)' interactivity
/// via `venue.updateSurface()`'s `isInteractive` option. Once enabled, the
/// SDK itself handles the hover/tap color swap directly on the 3D map — no
/// click listener is wired up on this side, unlike `goto-poi`'s
/// `selectionColor` highlight which is set once and never changes on its
/// own. See docs/features/clickable-surface.md.
struct ClickableSurfaceOverlay: View {
    @ObservedObject var bridge: VisioOneBridge
    @State private var placeId = ""

    var body: some View {
        HStack {
            TextField("Place ID", text: $placeId)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)

            Button("Enable") {
                setInteractive(true)
            }
            .disabled(placeId.trimmingCharacters(in: .whitespaces).isEmpty)

            Button("Disable") {
                setInteractive(false)
            }
            .disabled(placeId.trimmingCharacters(in: .whitespaces).isEmpty)
        }
        .padding()
    }

    private func setInteractive(_ isInteractive: Bool) {
        let targetPlaceId = placeId.trimmingCharacters(in: .whitespaces)
        guard !targetPlaceId.isEmpty else { return }
        bridge.setSurfaceInteractive(targetPlaceId, isInteractive: isInteractive)
    }
}

/// Lets the user type a POI ID and load its business CustomData (free
/// key/value strings such as price, opening hours, product reference), via
/// `venue.refreshCustomData()` + `venue.getPOICustomData()`. A single "Load"
/// button runs both SDK calls in sequence — this repo's `goto-poi`/
/// `clickable-surface` idiom of one field + one action, rather than
/// splitting "refresh" and "look up" into two separate buttons, since the
/// cache almost always needs refreshing right before a lookup anyway. See
/// docs/features/custom-data.md.
///
/// This screen loads a dedicated map (`Feature.customData.mapHashOverride`,
/// threaded through by `FeatureMapView`/`MapWebView`) rather than the app's
/// shared demo map, because the shared map has no CustomData published —
/// looking up any POI there would always land on the empty state. The 3
/// `knownPlaceIds` below are confirmed to carry real CustomData on that
/// dedicated map (see docs/features/custom-data.md), offered as quick-select
/// chips so opening this screen and tapping one + "Load" shows real,
/// non-empty data with minimal effort, while the text field still accepts
/// any other POI ID.
struct CustomDataOverlay: View {
    /// POI IDs confirmed to carry real CustomData on the dedicated map this
    /// screen loads. See docs/features/custom-data.md.
    private static let knownPlaceIds = ["B1", "B3-UL00-ID0065", "B3-UL00-ID0064"]

    @ObservedObject var bridge: VisioOneBridge
    @State private var placeId = ""
    @State private var isLoading = false
    @State private var lookup: CustomDataLookup?
    @State private var loadFailed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            knownPlaceIdChips

            HStack {
                TextField("Place ID", text: $placeId)
                    .textFieldStyle(.roundedBorder)
                    .autocorrectionDisabled()
                    .textInputAutocapitalization(.never)
                    .disabled(isLoading)

                Button("Load") {
                    load()
                }
                .disabled(isLoading || placeId.trimmingCharacters(in: .whitespaces).isEmpty)
            }

            resultView
        }
        .padding()
    }

    private var knownPlaceIdChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(Self.knownPlaceIds, id: \.self) { knownPlaceId in
                    Button(knownPlaceId) {
                        placeId = knownPlaceId
                        load()
                    }
                    .font(.footnote)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 6)
                    .background(Capsule().fill(Color.accentColor.opacity(0.15)))
                    .disabled(isLoading)
                }
            }
        }
    }

    @ViewBuilder
    private var resultView: some View {
        if isLoading {
            ProgressView()
                .frame(maxWidth: .infinity, alignment: .center)
        } else if loadFailed {
            Text("Could not load custom data")
                .foregroundStyle(.red)
        } else if let lookup {
            switch lookup {
            case .poiNotFound:
                Text("POI not found")
                    .foregroundStyle(.secondary)
            case .data(let data) where data.isEmpty:
                Text("No custom data for this POI")
                    .foregroundStyle(.secondary)
            case .data(let data):
                VStack(alignment: .leading, spacing: 6) {
                    ForEach(data.sorted(by: { $0.key < $1.key }), id: \.key) { key, value in
                        HStack(alignment: .top) {
                            Text(key)
                                .fontWeight(.semibold)
                            Spacer()
                            Text(value)
                                .multilineTextAlignment(.trailing)
                        }
                    }
                }
            }
        }
    }

    private func load() {
        let targetPlaceId = placeId.trimmingCharacters(in: .whitespaces)
        guard !targetPlaceId.isEmpty else { return }

        isLoading = true
        loadFailed = false
        lookup = nil

        Task {
            let result = await bridge.loadCustomData(targetPlaceId)
            isLoading = false
            if let result {
                lookup = result
            } else {
                loadFailed = true
            }
        }
    }
}

/// Lets the user pick one of the venue's categories (`venue.categories`) and
/// highlight every POI belonging to it in one action, via
/// `venue.pois.filter(poi => poi.categories.some(...))` +
/// `venue.updateSurface()`. Rows show each category's translated display
/// name (`MapCategory.label`), while selection/highlighting is keyed off its
/// raw `id` — the two differ on this app's shared demo map (see
/// docs/features/category-highlight.md). Picking a different category
/// automatically reverts the previous one first (enforced JS-side, see
/// `map.html`); picking the already-selected category, or tapping "Clear",
/// reverts to no highlight.
struct CategoryHighlightOverlay: View {
    @ObservedObject var bridge: VisioOneBridge
    @State private var categories: [MapCategory] = []
    @State private var isLoading = true
    @State private var loadFailed = false

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            if isLoading {
                ProgressView()
                    .frame(maxWidth: .infinity, alignment: .center)
                    .padding()
            } else if loadFailed {
                Text("Could not load categories")
                    .foregroundStyle(.red)
                    .padding()
            } else if categories.isEmpty {
                Text("No categories on this map")
                    .foregroundStyle(.secondary)
                    .padding()
            } else {
                List(categories) { category in
                    Button {
                        select(category)
                    } label: {
                        HStack {
                            Text(category.label)
                            Spacer()
                            if category.id == bridge.highlightedCategoryId {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                    .foregroundStyle(.primary)
                }
                .listStyle(.plain)

                if bridge.highlightedCategoryId != nil {
                    Button("Clear") {
                        bridge.clearCategoryHighlight()
                    }
                    .frame(maxWidth: .infinity)
                    .buttonStyle(.bordered)
                    .padding()
                }
            }
        }
        .task {
            await loadCategories()
        }
    }

    private func loadCategories() async {
        isLoading = true
        loadFailed = false
        let result = await bridge.getCategories()
        isLoading = false
        if let result {
            categories = result
        } else {
            loadFailed = true
        }
    }

    private func select(_ category: MapCategory) {
        if bridge.highlightedCategoryId == category.id {
            bridge.clearCategoryHighlight()
        } else {
            bridge.highlightCategory(category.id)
        }
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

/// Lets the user create, edit the label text of, and remove a single
/// "dynamic" POI at runtime, without republishing the map in VisioMapEditor
/// -- see docs/features/dynamic-poi-crud.md. Three fields (New POI ID,
/// Anchor POI ID, Label text) plus Create/Update text/Remove actions.
///
/// Only one dynamic POI is tracked at a time (`bridge.dynamicPOI`, see
/// `VisioOneBridge.swift`) -- the simplest demo state, same choice as
/// `goto-poi`'s `selectedPoi` and `category-highlight`'s
/// `highlightedCategoryId`. Create is disabled whenever one is already
/// tracked; a duplicate id (`POIAlreadyExistsError` on the SDK side) and an
/// unresolved/position-less anchor POI are shown as plain inline states,
/// not crashes.
struct DynamicPoiCrudOverlay: View {
    @ObservedObject var bridge: VisioOneBridge
    @State private var newPoiId = ""
    @State private var anchorPoiId = ""
    @State private var labelText: String
    @State private var isCreating = false
    @State private var createError: String?

    init(bridge: VisioOneBridge) {
        self.bridge = bridge
        // Seeds the field from whatever's already tracked, so reopening this
        // sheet after a previous Create still shows (and can re-submit) the
        // current label text via "Update text" -- this view is recreated
        // fresh every time the sheet opens (see FeatureMapView.swift), while
        // `bridge.dynamicPOI` itself persists across that.
        _labelText = State(initialValue: bridge.dynamicPOI?.labelText ?? "")
    }

    private var hasDynamicPOI: Bool { bridge.dynamicPOI != nil }

    private var trimmedNewPoiId: String { newPoiId.trimmingCharacters(in: .whitespaces) }
    private var trimmedAnchorPoiId: String { anchorPoiId.trimmingCharacters(in: .whitespaces) }
    private var trimmedLabelText: String { labelText.trimmingCharacters(in: .whitespaces) }

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            statusText

            TextField("New POI ID", text: $newPoiId)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .disabled(hasDynamicPOI || isCreating)

            TextField("Anchor POI ID", text: $anchorPoiId)
                .textFieldStyle(.roundedBorder)
                .autocorrectionDisabled()
                .textInputAutocapitalization(.never)
                .disabled(hasDynamicPOI || isCreating)

            TextField("Label text", text: $labelText)
                .textFieldStyle(.roundedBorder)
                .disabled(isCreating)

            if let createError {
                Text(createError)
                    .font(.footnote)
                    .foregroundStyle(.red)
            }

            HStack {
                Button("Create") {
                    create()
                }
                .disabled(hasDynamicPOI || isCreating || trimmedNewPoiId.isEmpty || trimmedAnchorPoiId.isEmpty || trimmedLabelText.isEmpty)

                Button("Update text") {
                    bridge.updateDynamicLabelText(trimmedLabelText)
                }
                .disabled(!hasDynamicPOI || trimmedLabelText.isEmpty)

                Button("Remove", role: .destructive) {
                    remove()
                }
                .disabled(!hasDynamicPOI)
            }
            .buttonStyle(.bordered)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding()
    }

    @ViewBuilder
    private var statusText: some View {
        if let dynamicPOI = bridge.dynamicPOI {
            Text("Created: `\(dynamicPOI.id)` — \"\(dynamicPOI.labelText)\"")
                .font(.footnote)
                .foregroundStyle(.secondary)
        } else {
            Text("No dynamic POI created yet")
                .font(.footnote)
                .foregroundStyle(.secondary)
        }
    }

    private func create() {
        let id = trimmedNewPoiId
        let anchor = trimmedAnchorPoiId
        let text = trimmedLabelText
        guard !id.isEmpty, !anchor.isEmpty, !text.isEmpty else { return }

        isCreating = true
        createError = nil

        Task {
            let result = await bridge.createDynamicPOI(newId: id, anchorId: anchor, labelText: text)
            isCreating = false
            switch result {
            case .created:
                newPoiId = ""
                anchorPoiId = ""
            case .duplicate:
                createError = "A POI with id \"\(id)\" already exists"
            case .anchorNotFound:
                createError = "Anchor POI \"\(anchor)\" not found"
            case .noPosition:
                createError = "Anchor POI has no position to copy"
            case .bridgeFailure:
                createError = "Could not create the POI"
            }
        }
    }

    private func remove() {
        bridge.removeDynamicPOI()
        newPoiId = ""
        anchorPoiId = ""
        labelText = ""
        createError = nil
    }
}

/// One switchable locale option offered by `RuntimeLocaleOverlay` below.
/// The shared demo map's `venue.translator.allLocales` is `['en', 'fr']`;
/// `'default'` isn't even listed there, yet it's still a working locale
/// value that renders byte-identical POI/label text to `'fr'` on this map
/// (both French) -- confirmed live. It's deliberately not offered here as a
/// third, meaningfully-different choice. See docs/features/runtime-locale.md.
struct MapLocaleOption: Identifiable {
    let code: String
    let label: String
    var id: String { code }
}

private let runtimeLocaleOptions = [
    MapLocaleOption(code: "en", label: "English"),
    MapLocaleOption(code: "fr", label: "Français"),
]

/// Lets the user switch the map's displayed language (POI/label text) at
/// runtime via `venue.setCurrentLocale()`, no reload/republish needed --
/// see docs/features/runtime-locale.md. Reads the venue's current locale
/// once (`bridge.currentLocale`, kept on the bridge so it survives the
/// sheet being dismissed and reopened, same idiom as
/// `CategoryHighlightOverlay`'s `highlightedCategoryId`), then shows a
/// checkmark next to whichever of the two offered options matches it.
struct RuntimeLocaleOverlay: View {
    @ObservedObject var bridge: VisioOneBridge
    @State private var isSwitching = false

    var body: some View {
        List(runtimeLocaleOptions) { option in
            Button {
                switchLocale(to: option.code)
            } label: {
                HStack {
                    Text(option.label)
                    Spacer()
                    if option.code == bridge.currentLocale {
                        Image(systemName: "checkmark")
                    }
                }
            }
            .foregroundStyle(.primary)
            .disabled(isSwitching || option.code == bridge.currentLocale)
        }
        .listStyle(.plain)
        .task {
            guard bridge.currentLocale == nil else { return }
            await bridge.refreshCurrentLocale()
        }
    }

    private func switchLocale(to code: String) {
        isSwitching = true
        Task {
            await bridge.setCurrentLocale(code)
            isSwitching = false
        }
    }
}
