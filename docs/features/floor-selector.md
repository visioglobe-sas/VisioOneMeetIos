# Sélection d'étage / bâtiment

## Description

Change d'étage (et de bâtiment, quand la venue en a plusieurs) via `view.goToFloor(floor)` / `view.goToBuilding(building)` du SDK, pilotés depuis une liste native dans le bottom sheet — un bouton par étage du bâtiment actif (et, si la venue a plus d'un bâtiment, une liste de bâtiments au-dessus), avec l'entrée courante mise en évidence.

Les étages/bâtiments viennent de la venue réellement chargée (`venue.venueLayout.buildings`), jamais d'IDs codés en dur : la carte n'a aucune notion d'étage/bâtiment avant que le SDK ait fini de charger la venue. Réutilise le pont natif→JS existant (`window.MapBridge` + `VisioOneBridge.evaluateJavaScript`) pour le sens natif→JS (deux commandes : `goToFloor(floorId)`, `goToBuilding(buildingId)`), et ajoute un nouveau canal JS→natif (`floorsChanged`, sur le modèle de `poiSelected`) pour que Swift reçoive la liste des bâtiments/étages ainsi que ce qui est actif — ni codé en dur, ni interrogé à la demande.

Le SDK affiche **déjà lui-même** un sélecteur d'étage par défaut, directement sur la carte, sans une ligne de code côté app (`view.setUIPartVisible('floorSelector', false)` pour le masquer). Cette feature n'ajoute donc rien de fonctionnellement nouveau à l'utilisateur final — elle démontre que l'app peut piloter `goToFloor`/`goToBuilding` elle-même, ce qui est nécessaire dès qu'un client veut son propre contrôle (design custom, icônes de marque, intégré à un autre écran, etc.) plutôt que le widget du SDK. Voir "Points d'attention" pour le détail de cette cohabitation.

## Step by step

1. **Ajouter l'état et les deux commandes côté JS** (`VisioOneMeet/WebContent/map.html`), dans `window.MapBridge` et deux fonctions utilitaires :
   ```js
   // Un ID d'étage est unique dans toute la venue (pas seulement dans son
   // bâtiment) : FloorAdapter.retrieveFloorFromID côté SDK le confirme en
   // cherchant dans tous les bâtiments sans distinction.
   function findFloorById(floorId) {
     if (!venue) return null;
     var buildings = venue.venueLayout.buildings;
     for (var i = 0; i < buildings.length; i++) {
       var floor = buildings[i].floors.find(function (f) { return f.id === floorId; });
       if (floor) return floor;
     }
     return null;
   }

   function sendFloorsState() {
     if (!venue || !view) return;
     var locale = venue.currentLocale;
     var buildings = venue.venueLayout.buildings.map(function (building) {
       var label = venue.translator.translateBuilding(building, locale).name || building.id;
       var floors = building.floors
         .slice()
         .sort(function (a, b) { return b.altitude - a.altitude; }) // haut -> bas
         .map(function (floor) {
           var shortName = venue.translator.translateFloor(floor, locale).shortName;
           return { id: floor.id, label: shortName || String(floor.levelIndex) };
         });
       return { id: building.id, label: label, floors: floors };
     });

     sendToNative('floorsChanged', {
       buildings: buildings,
       currentBuildingId: view.currentBuilding ? view.currentBuilding.id : null,
       currentFloorId: view.currentFloor ? view.currentFloor.id : null,
     });
   }

   window.MapBridge = {
     // ...
     goToFloor: function (floorId) {
       if (!venue || !view) return;
       var floor = findFloorById(floorId);
       if (!floor) return;
       view.goToFloor(floor);
     },
     goToBuilding: function (buildingId) {
       if (!venue || !view) return;
       var building = venue.venueLayout.buildings.find(function (b) { return b.id === buildingId; });
       if (!building) return;
       view.goToBuilding(building);
     },
   };
   ```
2. **Pousser l'état au bon moment** : une fois après `createView` (`sendToNative('ready'); sendFloorsState();`), puis à chaque fois que le SDK change d'étage courant — y compris quand ce changement vient d'ailleurs que de nos deux commandes (le widget par défaut du SDK, une navigation, un autre écran) :
   ```js
   view.addEventListener('currentfloorchanged', function () {
     sendFloorsState();
   });
   ```
   `currentfloorchanged` couvre aussi le changement de bâtiment (l'event expose `newBuilding`/`newFloor` en plus de `oldBuilding`/`oldFloor` — `view.goToBuilding()` résout lui-même vers l'étage par défaut du bâtiment ciblé, donc déclenche ce même event, jamais un event séparé "changement de bâtiment").
3. **Ajouter les méthodes natif→JS et le message JS→natif** (`VisioOneMeet/VisioOneBridge.swift`) : deux méthodes `goToFloor(_:)`/`goToBuilding(_:)` sur le même modèle que `goToPOI` (encodage JSON via `.fragmentsAllowed`), plus trois nouveaux types (`VenueFloor`, `VenueBuilding`, `FloorSelection`) et une propriété `@Published private(set) var floorSelection: FloorSelection` mise à jour dans `userContentController(_:didReceive:)` sur le message `"floorsChanged"` :
   ```swift
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
       static let empty = FloorSelection(buildings: [], currentBuildingId: nil, currentFloorId: nil)
   }
   ```
   Le parsing (`parseFloorSelection`) ignore silencieusement une entrée malformée (`compactMap`) plutôt que de faire échouer tout le payload — un seul bâtiment/étage inattendu ne doit pas vider toute la liste.
4. **Overlay dédié** (`FloorSelectorOverlay` dans `VisioOneMeet/FeatureOverlays.swift`) : une section "Building" (seulement si `buildings.count > 1`) suivie d'une section "Floor" listant les étages du bâtiment actif (`currentBuildingId`, ou le premier bâtiment par défaut) — chaque entrée est un bouton pleine largeur, coché/en surbrillance si son `id` correspond à `currentBuildingId`/`currentFloorId`, qui appelle `bridge.goToBuilding(id)`/`bridge.goToFloor(id)` au tap. Le tout dans un `ScrollView` (liste potentiellement longue), dans le bottom sheet ouvert par le FAB par défaut de `FeatureMapView` (aucune logique spéciale requise, contrairement à `poi-click`).
5. **Enregistrer la feature** dans `Feature.swift` (`case floorSelector`, slug `floor-selector`), dans le `switch` de `FeatureMapView.swift` (`case .floorSelector: FloorSelectorOverlay(bridge: bridge)`), et dans `Localizable.xcstrings` (`feature.floor_selector.title` / `.description`, EN + FR).

## Points d'attention

- **Cohabitation avec le sélecteur d'étage par défaut du SDK** : le SDK affiche son propre widget flottant (généralement en haut à droite de la carte) sans code app, tant que `view.setUIPartVisible('floorSelector', false)` n'est pas appelé — ce qui n'est **pas** fait ici, volontairement, pour que les deux coexistent et restent synchronisés (taper une entrée native ou le widget SDK déclenchent le même `currentfloorchanged`, qui rafraîchit les deux). Le but de cette feature est de démontrer le pilotage natif de `goToFloor`/`goToBuilding`, pas de remplacer l'UI du SDK — un client qui veut un remplacement complet ajouterait cet appel lui-même.
- **Les IDs d'étage sont uniques dans toute la venue, pas seulement dans leur bâtiment** — `findFloorById` peut donc chercher à travers tous les bâtiments sans avoir besoin d'un `buildingId` en paramètre de `goToFloor`. Ce n'est pas le cas de tout ce qui est adressé par ID dans le SDK (à vérifier au cas par cas).
- **`venue.venueLayout.buildings`, pas `venue.buildings`** : la liste des bâtiments/étages passe par `venueLayout` (résultat de `parseVenueLayout()` en interne), une subtilité qu'on ne devine pas depuis les autres features déjà en place (`goto-poi` n'a besoin que de `venue.pois` et `poi.floor`, jamais de `venueLayout` directement).
- **Labels déjà localisés côté JS** : `venue.translator.translateFloor(floor, locale).shortName` / `translateBuilding(building, locale).name` — c'est exactement ce que fait le widget par défaut du SDK en interne pour afficher ses propres boutons. Repris ici plutôt que de renvoyer un ID brut à Swift et laisser l'app le traduire elle-même, ce qui dupliquerait une logique de traduction déjà fournie par le SDK. `shortName` peut être vide selon les données de la venue ; on retombe alors sur `floor.levelIndex` (jamais une chaîne vide affichée).
- **Tri des étages par altitude descendante** (`floors.slice().sort((a,b) => b.altitude - a.altitude)`) pour afficher la liste dans l'ordre naturel haut → bas, comme le fait le widget par défaut du SDK — sans ce tri, l'ordre dépendrait de l'ordre de déclaration des étages dans les données de la venue, pas de leur position réelle.
- **`currentfloorchanged` couvre aussi bien le changement d'étage que de bâtiment** : il n'existe pas d'event `currentbuildingchanged` séparé — `view.goToBuilding()` résout en interne vers l'étage par défaut du bâtiment ciblé (son `defaultFloorID`) et déclenche donc ce même event. Un seul listener suffit pour tenir `floorSelection` à jour dans tous les cas.
- **La venue de démo actuelle n'a qu'un seul bâtiment** : la section "Building" de l'overlay ne s'affiche donc pas en pratique (`buildings.count > 1` est faux) — le code est écrit pour rester correct sur une venue multi-bâtiments sans avoir pu être testé visuellement sur une telle venue avec les données actuelles. À revérifier visuellement si la venue de démo change.
- **`FloorSelection.empty` avant que le SDK n'ait chargé la venue** : contrairement à `goto-poi`/`occupancy-simulated` qui n'ont besoin de rien avant que l'utilisateur tape un ID, cette feature a besoin d'attendre `sendFloorsState()` (poussé juste après `ready`) avant d'avoir quoi que ce soit à afficher — l'overlay affiche donc un message d'attente ("No building/floor data yet") plutôt qu'une liste vide silencieuse, pour rendre visible qu'aucune donnée n'est encore arrivée si le FAB est ouvert très tôt.

## Pour aller plus loin

- Voir `docs/features/goto-poi.md` pour l'autre usage de `view.goToFloor()` dans ce dépôt (changer d'étage avant de cibler un POI qui n'est pas sur l'étage courant) — les deux features appellent la même méthode SDK avec le même objet `Floor`, mais dans des buts différents (naviguer manuellement vs. pré-requis technique avant `goToPOI`).
- Le pont pourrait aussi exposer `view.currentExploreMode` (`"floor"` vs `"building"`, ce dernier étant la vue zoomée où plusieurs bâtiments sont visibles à la fois et où `goToFloor` seul ne suffit pas) si une démo voulait aussi piloter ce mode d'exploration — non fait ici pour rester une démonstration minimale du bridge, cohérent avec les choix déjà faits sur `occupancy-simulated`/`goto-poi`.
