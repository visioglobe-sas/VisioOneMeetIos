import SwiftUI

/// Lets the user switch floor (and building, when the venue has more than
/// one) by tapping a native list, via `view.goToFloor()`/`view.goToBuilding()`.
/// This is deliberately separate from the SDK's own default floor-selector
/// widget, which keeps working alongside this one. native-ui-replacement
/// reuses this exact list rather than reimplementing it -- the whole point of
/// that feature is demonstrating this native UI as a drop-in replacement for
/// the SDK's widget. See docs/features/floor-selector.md and
/// docs/features/native-ui-replacement.md.
struct FloorSelectorList: View {
    @ObservedObject var model: FloorSelectorModel

    private var selection: FloorSelection { model.floorSelection }

    private var buildings: [VenueBuilding] { selection.buildings }

    private var currentBuilding: VenueBuilding? {
        buildings.first { $0.id == selection.currentBuildingId } ?? buildings.first
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
                    isSelected: building.id == selection.currentBuildingId
                ) {
                    model.bridge.goToBuilding(building.id)
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
                    isSelected: floor.id == selection.currentFloorId
                ) {
                    model.bridge.goToFloor(floor.id)
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
