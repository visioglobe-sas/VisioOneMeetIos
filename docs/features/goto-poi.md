# Aller à un lieu / POI

## Description

Centre et zoome la caméra sur un POI donné par son ID, via `view.goToPOI(poi, animationOptions)` du SDK, avec un champ **Place ID** + boutons **Go**/**Clear** dans le bottom sheet — même UX que `occupancy-simulated`. `view.goToPOI` déplace uniquement la caméra ; cette feature ajoute en plus un surlignage (`selectionColor`) sur les surfaces du POI ciblé, pour que le résultat reste visible une fois la caméra arrivée, et un changement d'étage préalable (`view.goToFloor`) quand le POI n'est pas sur l'étage courant — voir "Points d'attention".

Réutilise le pont natif→JS existant (`window.MapBridge` + `VisioOneBridge.evaluateJavaScript`, introduit par `occupancy-simulated`) : deux nouvelles méthodes natif→JS (`goToPOI`, `clearPOI`), aucun nouveau canal JS→natif (contrairement à `poi-click`, cette feature n'a pas besoin de remonter de donnée depuis le SDK).

## Step by step

1. **Ajouter les deux commandes côté JS** (`VisioOneMeet/WebContent/map.html`), dans `window.MapBridge` :
   ```js
   var selectedPoi = null; // POI actuellement surligné, pour que clearPOI sache quoi réinitialiser

   window.MapBridge = {
     // ...
     goToPOI: function (poiId) {
       if (!venue || !view) return;
       var poi = venue.pois.find(function (p) { return p.id === poiId; });
       if (!poi) return;

       if (selectedPoi) {
         selectedPoi.surfaces.forEach(function (surface) {
           venue.updateSurface(surface, { selectionColor: undefined });
         });
       }
       selectedPoi = poi;
       poi.surfaces.forEach(function (surface) {
         venue.updateSurface(surface, { selectionColor: '#057DBC' });
       });

       // Le SDK est explicite : à l'appelant de changer d'étage avant
       // goToPOI, sinon currentFloor/Building reste inchangé.
       var floorChange = poi.floor ? view.goToFloor(poi.floor) : Promise.resolve();
       floorChange.then(function () {
         view.goToPOI(poi, {
           orientation: { pitch: 20 },
           padding: { top: 100, bottom: 100, right: 100, left: 100 },
         });
       });
     },
     clearPOI: function () {
       if (!venue || !selectedPoi) return;
       selectedPoi.surfaces.forEach(function (surface) {
         venue.updateSurface(surface, { selectionColor: undefined });
       });
       selectedPoi = null;
     },
   };
   ```
2. **Ajouter les méthodes natif→JS correspondantes** (`VisioOneMeet/VisioOneBridge.swift`), même style que `updateOccupancy`/`goToGlobal` déjà en place :
   ```swift
   func goToPOI(_ poiId: String) {
       guard let webView else { return }
       guard let data = try? JSONSerialization.data(withJSONObject: poiId, options: [.fragmentsAllowed]),
             let json = String(data: data, encoding: .utf8) else { return }
       webView.evaluateJavaScript("window.MapBridge.goToPOI(\(json))") { _, error in
           if let error {
               print("VisioOneBridge: goToPOI failed: \(error.localizedDescription)")
           }
       }
   }

   func clearPOI() {
       webView?.evaluateJavaScript("window.MapBridge.clearPOI()") { _, error in
           if let error {
               print("VisioOneBridge: clearPOI failed: \(error.localizedDescription)")
           }
       }
   }
   ```
   `JSONSerialization.data(withJSONObject:options:[.fragmentsAllowed])` encode directement une `String` Swift en littéral JS (guillemets + échappement corrects), sans avoir à l'enrober dans un tableau/dictionnaire juste pour satisfaire l'API — l'option `.fragmentsAllowed` est ce qui permet un fragment JSON de premier niveau (une simple string) plutôt qu'un objet/tableau.
3. **Overlay dédié** (`GoToPoiOverlay` dans `VisioOneMeet/FeatureOverlays.swift`) : un `TextField` "Place ID" + bouton **Go** (désactivé si le champ est vide/blanc) + bouton **Clear**, tous les deux dans le bottom sheet ouvert par le FAB (comportement par défaut de `FeatureMapView` — cette feature n'a pas besoin de logique spéciale comme `poi-click`, qui masque le FAB) :
   ```swift
   struct GoToPoiOverlay: View {
       @ObservedObject var bridge: VisioOneBridge
       @State private var placeId = ""

       var body: some View {
           HStack {
               TextField("Place ID", text: $placeId)
                   .textFieldStyle(.roundedBorder)
                   .autocorrectionDisabled()
                   .textInputAutocapitalization(.never)

               Button("Go") { bridge.goToPOI(placeId.trimmingCharacters(in: .whitespaces)) }
                   .disabled(placeId.trimmingCharacters(in: .whitespaces).isEmpty)

               Button("Clear") { bridge.clearPOI() }
           }
           .padding()
       }
   }
   ```
   "Clear" n'efface pas le champ texte — il ne fait qu'annuler le surlignage côté carte, comme le `clearPlace` du sibling React Native (le champ reste rempli, pratique pour retaper "Go" sur le même lieu).
4. **Enregistrer la feature** dans `Feature.swift` (`case goToPoi`, slug `goto-poi`), dans le `switch` de `FeatureMapView.swift` (`case .goToPoi: GoToPoiOverlay(bridge: bridge)`), et dans `Localizable.xcstrings` (`feature.goto_poi.title` / `.description`, EN + FR).

## Points d'attention

- **`view.goToFloor` avant `view.goToPOI` n'est pas optionnel** : la doc TypeScript du SDK est explicite — « the caller is responsible to call goToFloor prior goToPOI, otherwise the currentFloor/Building will remain active ». Sur une carte mono-étage (comme la venue de démo actuelle) ça ne se voit pas, mais sans ce changement d'étage préalable, cibler un POI d'un étage non affiché déplacerait la caméra vers des coordonnées qui n'apparaissent nulle part à l'écran (étage courant inchangé). D'où le `poi.floor ? view.goToFloor(poi.floor) : Promise.resolve()` avant le `.then(goToPOI)`.
- **`goToFloor`/`goToPOI` renvoient un `AnimationPromise`** (qui étend `Promise<void>`, avec en plus `isCanceled`/`cancel()`) — `.then()` fonctionne donc directement dessus sans conversion.
- **Le surlignage (`selectionColor`) est une amélioration UX, pas une exigence du SDK** : `goToPOI` seul ne fait que déplacer la caméra ; sans surlignage, une fois arrivé il n'y a aucune indication visuelle de *quel* POI a été ciblé parmi ceux visibles à l'écran. Le sibling React Native ajoute en plus un marqueur image (`venue.createImage`) — non repris ici pour rester une démonstration minimale du bridge, cohérent avec le choix déjà fait sur `occupancy-simulated`.
- **`selectedPoi` doit être réinitialisé avant de surligner le suivant** : sans ce nettoyage (`selectedPoi.surfaces.forEach(...selectionColor: undefined...)` avant de réassigner `selectedPoi`), taper un second Place ID laisserait le premier POI surligné indéfiniment.
- **`JSONSerialization.data(withJSONObject: poiId, options: [.fragmentsAllowed])`** : sans cette option, `JSONSerialization` refuse un objet racine qui n'est ni un `Array` ni un `Dictionary` (une simple `String` ne suffit pas par défaut) — c'est le seul détail qui distingue cet encodage de celui d'`updateOccupancy`, qui encode un tableau de dictionnaires et n'a pas besoin de l'option.
- **`placeId` doit être un vrai ID de POI de la carte chargée** — comme pour `occupancy-simulated`, `venue.pois.find(...)` échoue silencieusement côté JS (aucun message d'erreur remonté) si l'ID ne correspond à rien ; le bouton "Go" ne donne alors aucun retour visuel qu'il s'est passé quelque chose.
- **"Clear" ne recentre pas la caméra** : c'est un choix délibéré pour rester distinct de `reset-view` (qui existe déjà comme feature séparée) — "Clear" n'annule que le surlignage laissé par "Go", il ne touche pas au point de vue.

## Pour aller plus loin

- Même pont natif→JS réutilisable pour `goToFloor`/`goToBuilding` (sélection d'étage/bâtiment), encore ❌ sur cette plateforme — voir `ROADMAP.md` du hub (`VisioOneHub`).
- Voir `docs/features/poi-click.md` pour le sens inverse (réagir à un tap sur la carte plutôt que cibler un POI depuis un champ natif) — les deux features sont complémentaires et partagent le même `window.MapBridge` comme point d'ancrage.
