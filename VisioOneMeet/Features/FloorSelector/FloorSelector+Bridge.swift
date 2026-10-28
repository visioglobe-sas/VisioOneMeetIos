import Foundation

extension VisioOneBridge {
    /// Switches floor within the currently active building via
    /// `view.goToFloor()` (see `docs/features/floor-selector.md`).
    func goToFloor(_ floorId: String) {
        call("goToFloor", args: [floorId])
    }

    /// Switches building via `view.goToBuilding()`, which resolves to that
    /// building's default floor (see `docs/features/floor-selector.md`).
    func goToBuilding(_ buildingId: String) {
        call("goToBuilding", args: [buildingId])
    }
}
