// floor-selector: the building/floor list pushed to native ('floorsChanged')
// and the goToFloor/goToBuilding commands behind the native picker. Reused
// as-is by native-ui-replacement. See docs/features/floor-selector.md.
(function (core) {
  // Finds a floor by ID across every building of the venue (floor IDs are
  // unique venue-wide, unlike POI IDs).
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

  // JS -> native: pushes the full building/floor list plus what's currently
  // active, so the native bottom sheet can render a list and highlight the
  // selected floor. Sent once on `ready`, then again on every
  // `currentfloorchanged` (which also fires on a building switch, since
  // `view.goToBuilding` resolves to that building's default floor).
  function sendFloorsState() {
    var venue = core.venue;
    var view = core.view;
    if (!venue || !view) return;
    var locale = venue.currentLocale;
    var buildings = venue.venueLayout.buildings.map(function (building) {
      var label = venue.translator.translateBuilding(building, locale).name || building.id;
      var floors = building.floors
        .slice()
        .sort(function (a, b) { return b.altitude - a.altitude; })
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

  // Refresh the floor-selector state whenever the active floor/building
  // changes, whichever triggered it (the goToFloor/goToBuilding commands
  // below, the SDK's own default floor-selector widget, or navigation).
  core.onViewCreated(function (view) {
    view.addEventListener('currentfloorchanged', function () {
      sendFloorsState();
    });
  });
  core.onReady(sendFloorsState);

  core.register({
    // Switches floor within the currently active building via
    // `view.goToFloor()`.
    goToFloor: function (floorId) {
      if (!core.venue || !core.view) return;
      var floor = findFloorById(floorId);
      if (!floor) return;
      core.view.goToFloor(floor);
    },
    // Switches building via `view.goToBuilding()`, which resolves to that
    // building's default floor.
    goToBuilding: function (buildingId) {
      var venue = core.venue;
      if (!venue || !core.view) return;
      var building = venue.venueLayout.buildings.find(function (b) { return b.id === buildingId; });
      if (!building) return;
      core.view.goToBuilding(building);
    },
  });
})(window.MapCore);
