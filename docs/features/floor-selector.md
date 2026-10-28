# Floor/Building Selector

## Description

Changes floor (and building, when the venue has more than one) via `view.goToFloor(floor)` / `view.goToBuilding(building)`. Floor/building data comes from the actually-loaded venue (`venue.venueLayout.buildings`), never hardcoded IDs — the map has no notion of floors/buildings until the SDK finishes loading the venue.

## SDK usage

```js
// VisioOneMeet/WebContent/features/floor-selector.js

// A floor ID is unique across the whole venue, not just within its building.
function findFloorById(floorId) {
  var venue = core.venue;
  if (!venue) return null;
  var buildings = venue.venueLayout.buildings;
  for (var i = 0; i < buildings.length; i++) {
    var floor = buildings[i].floors.find(function (f) { return f.id === floorId; });
    if (floor) return floor;
  }
  return null;
}

function sendFloorsState() {
  var venue = core.venue;
  var view = core.view;
  if (!venue || !view) return;
  var locale = venue.currentLocale;
  var buildings = venue.venueLayout.buildings.map(function (building) {
    var label = venue.translator.translateBuilding(building, locale).name || building.id;
    var floors = building.floors
      .slice()
      .sort(function (a, b) { return b.altitude - a.altitude; }) // top -> bottom
      .map(function (floor) {
        var shortName = venue.translator.translateFloor(floor, locale).shortName;
        return { id: floor.id, label: shortName || String(floor.levelIndex) };
      });
    return { id: building.id, label: label, floors: floors };
  });

  core.sendToNative('floorsChanged', {
    buildings: buildings,
    currentBuildingId: view.currentBuilding ? view.currentBuilding.id : null,
    currentFloorId: view.currentFloor ? view.currentFloor.id : null,
  });
}

// Push state once after createView (onReady), and again on every subsequent
// change -- including changes triggered by something other than the two
// commands below (the SDK's own default floor selector widget, a computed
// route, ...).
core.onViewCreated(function (view) {
  view.addEventListener('currentfloorchanged', function () {
    sendFloorsState();
  });
});
core.onReady(sendFloorsState);

core.register({
  goToFloor: function (floorId) {
    if (!core.venue || !core.view) return;
    var floor = findFloorById(floorId);
    if (!floor) return;
    core.view.goToFloor(floor);
  },
  goToBuilding: function (buildingId) {
    var venue = core.venue;
    if (!venue || !core.view) return;
    var building = venue.venueLayout.buildings.find(function (b) { return b.id === buildingId; });
    if (!building) return;
    core.view.goToBuilding(building);
  },
});
```

```swift
// VisioOneMeet/Features/FloorSelector/FloorSelector+Bridge.swift
extension VisioOneBridge {
    func goToFloor(_ floorId: String) {
        call("goToFloor", args: [floorId])
    }

    func goToBuilding(_ buildingId: String) {
        call("goToBuilding", args: [buildingId])
    }
}
```

The `floorsChanged` payload comes back through the bridge's `WKScriptMessageHandler` (see `docs/features/loading-state.md`) and is parsed by `FloorSelectorModel` into:

```swift
// VisioOneMeet/Features/FloorSelector/FloorSelectorModel.swift
struct VenueFloor: Equatable, Identifiable {
    let id: String
    let label: String
}

struct VenueBuilding: Equatable, Identifiable {
    let id: String
    let label: String
    let floors: [VenueFloor]
}

struct FloorSelection: Equatable {
    let buildings: [VenueBuilding]
    let currentBuildingId: String?
    let currentFloorId: String?
}

bridge.onMessage("floorsChanged") { [weak self] payload in
    guard let payload = payload as? [String: Any] else { return }
    self?.floorSelection = Self.parseFloorSelection(payload)
}
```

## Things to know

- **Floor IDs are unique across the whole venue, not just within their building** — `findFloorById` searches across all buildings without needing a `buildingId` parameter. This isn't necessarily true of every ID-addressed entity in the SDK; check case by case.
- **Building/floor data lives under `venue.venueLayout.buildings`, not `venue.buildings`.**
- **`currentfloorchanged` covers building changes too** — there is no separate `currentbuildingchanged` event. `view.goToBuilding()` internally resolves to that building's default floor, which triggers this same event.
- **Labels are already localized SDK-side**: `venue.translator.translateFloor(floor, locale).shortName` / `translateBuilding(building, locale).name` is the exact call the SDK's own default floor-selector widget uses internally to render its labels. `shortName` can be empty depending on the venue's data — fall back to `floor.levelIndex` rather than showing an empty string.
- **Sort floors by descending altitude** (`floors.slice().sort((a, b) => b.altitude - a.altitude)`) to list them top-to-bottom, matching the SDK's own widget — without this, order follows however floors happen to be declared in the venue's data, not their physical stacking.
- **The SDK shows its own default floor-selector widget on the map regardless**, unless `view.setUIPartVisible('floorSelector', false)` is called (see `docs/features/ui-part-visibility.md`) — tapping either a native entry or the SDK's own widget fires the same `currentfloorchanged` event, so both stay in sync automatically.

## Learn more

- `view.currentExploreMode` (`"floor"` vs `"building"`, the latter being the zoomed-out view where several buildings are visible and `goToFloor` alone isn't enough) is not covered here.
- See `docs/features/goto-poi.md` for `view.goToFloor()` used as a prerequisite step before `goToPOI`, rather than as direct user-driven navigation.
- See `docs/features/ui-part-visibility.md` for hiding the SDK's own floor-selector widget.
