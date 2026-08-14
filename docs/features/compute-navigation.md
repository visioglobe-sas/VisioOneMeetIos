# Itinéraire

## Description

Calcule un itinéraire entre deux POIs donnés par leur ID et l'affiche sur la carte, via trois appels SDK enchaînés : `venue.computeNavigation(request)` (calcule les instructions), `venue.createNavigationTrace(navigation)` (crée la représentation visuelle), puis `view.setCurrentNavigationTrace(navigationTrace)` (l'affiche et la rend "courante"). Le bottom sheet expose deux champs **From**/**To** (Place ID) + un bouton **Itinerary**, même UX que le sibling React Native (`ComputeNavigationOverlay.tsx`).

Réutilise le pont natif→JS existant (`window.MapBridge` + `VisioOneBridge.evaluateJavaScript`, introduit par `occupancy-simulated`) : une nouvelle méthode natif→JS (`computeNavigation`), aucun nouveau canal JS→natif — contrairement au sibling React Native, cette démo n'a pas besoin de remonter les instructions de navigation (`navigation.instructions`) côté natif, puisqu'elles n'y sont pas affichées non plus (le sibling se contente d'un `console.log`) : la seule chose visible du résultat est le tracé sur la carte.

## Step by step

1. **Ajouter la commande côté JS** (`VisioOneMeet/WebContent/map.html`), dans `window.MapBridge` :
   ```js
   computeNavigation: function (request) {
     if (!venue || !view) return;
     var navigation = venue.computeNavigation({
       origin: request.origin,
       destination: request.destination,
       isAccessible: request.isAccessible,
       type: 'fastest',
       firstNodeAsIntersection: false,
       mergeFloorChangeInstructions: false,
     });
     var navigationTrace = venue.createNavigationTrace(navigation);
     view.setCurrentNavigationTrace(navigationTrace);
   },
   ```
   `request.origin`/`request.destination` peuvent être un Place ID (string), un POI, ou une `Position` — le type SDK `POIOrIDOrPosition` accepte les trois ; ici on passe toujours un ID puisque c'est ce que le champ natif collecte.
2. **Ajouter la méthode natif→JS correspondante** (`VisioOneMeet/VisioOneBridge.swift`), même style qu'`updateOccupancy` (un seul argument dictionnaire, JSON-encodé) :
   ```swift
   func computeNavigation(origin: String, destination: String, isAccessible: Bool) {
       guard let webView else { return }

       let request: [String: Any] = ["origin": origin, "destination": destination, "isAccessible": isAccessible]
       guard let data = try? JSONSerialization.data(withJSONObject: request),
             let json = String(data: data, encoding: .utf8) else { return }

       webView.evaluateJavaScript("window.MapBridge.computeNavigation(\(json))") { _, error in
           if let error {
               print("VisioOneBridge: computeNavigation failed: \(error.localizedDescription)")
           }
       }
   }
   ```
3. **Overlay dédié** (`ComputeNavigationOverlay` dans `VisioOneMeet/FeatureOverlays.swift`) : deux `TextField` ("From (Place ID)" / "To (Place ID)") + un bouton **Itinerary** (désactivé tant que l'un des deux champs est vide/blanc), dans le bottom sheet ouvert par le FAB par défaut de `FeatureMapView` — pas de logique spéciale requise, comme `goto-poi`/`floor-selector`. `isAccessible` est câblé en dur à `false` (même choix que le sibling React Native), pour rester une démonstration minimale du bridge plutôt que d'ajouter un toggle d'accessibilité dans l'UI.
4. **Enregistrer la feature** dans `Feature.swift` (`case computeNavigation`, slug `compute-navigation`), dans le `switch` de `FeatureMapView.swift` (`case .computeNavigation: ComputeNavigationOverlay(bridge: bridge)`), et dans `Localizable.xcstrings` (`feature.compute_navigation.title` / `.description`, EN + FR).

## Points d'attention

- **`view.setCurrentNavigationTrace()` remplace automatiquement la route précédente** : pas besoin d'appeler `view.removeCurrentNavigationTrace()` avant de calculer un nouvel itinéraire — l'implémentation SDK le fait elle-même en interne si une trace était déjà courante. Taper "Itinerary" une seconde fois avec d'autres IDs remplace donc proprement le tracé affiché, sans superposition de deux routes.
- **Aucun feedback visuel en cas d'échec** : `computeNavigation` peut lever `RouteNotFoundError`, `SourceOutOfLimitError` ou `DestinationOutOfLimitError` (Place ID invalide, POI hors des limites de routage, aucun chemin possible entre les deux, etc.). Ces erreurs ne sont pas interceptées côté JS ; elles remontent telles quelles à la closure de complétion d'`evaluateJavaScript` côté Swift, qui se contente de les logger dans la console Xcode (`print("VisioOneBridge: computeNavigation failed: ...")`) — même choix de simplicité que `goto-poi`/`occupancy-simulated`, qui échouent aussi silencieusement sur un ID inconnu. Un client voulant un message utilisateur ("itinéraire introuvable") devrait ajouter un canal JS→natif dédié (`try`/`catch` autour de l'appel SDK + `sendToNative('navigationError', ...)`), sur le modèle de `error`/`poiSelected`.
- **Pas de changement d'étage automatique avant le calcul** : contrairement à `goto-poi` (qui doit appeler `view.goToFloor()` avant `view.goToPOI()` sous peine de laisser la caméra sur un étage qui n'affiche rien), `computeNavigation`/`setCurrentNavigationTrace` n'ont pas cette contrainte — la trace de navigation gère elle-même l'affichage multi-étages du tracé (changements d'étage inclus dans les instructions), et la caméra n'est pas automatiquement déplacée par cette feature. L'utilisateur peut donc devoir naviguer manuellement vers l'étage du point de départ pour voir le début du tracé.
- **`origin`/`destination` doivent être de vrais Place ID de la carte chargée** — comme pour `goto-poi`, un ID qui ne correspond à aucun POI produit une erreur SDK (voir point ci-dessus), pas un no-op silencieux comme `venue.pois.find(...)` ailleurs dans ce pont.
- **`mergeFloorChangeInstructions: false` et `firstNodeAsIntersection: false`** : repris tels quels du sibling React Native pour un comportement identique entre les deux démos — ce ne sont pas des valeurs par défaut du SDK pour tous les champs (`mergeFloorChangeInstructions` n'a pas de valeur par défaut documentée, contrairement à `type: 'fastest'` et `isAccessible: false`), donc explicitement fournies.
- **Pas de bouton "Clear"** : contrairement à `goto-poi`, cette feature ne propose pas de retirer le tracé affiché — chaque écran de feature recrée sa propre WebView/carte (voir `CLAUDE.md` du hub), donc revenir au menu puis rouvrir "Itinéraire" repart d'une carte sans aucun tracé. Un client voulant un contrôle explicite ajouterait un bouton appelant `view.removeCurrentNavigationTrace()` côté JS.

## Pour aller plus loin

- Voir `docs/features/goto-poi.md` pour l'autre usage de POI ciblés par ID dans ce dépôt, et pour le détail du changement d'étage préalable que `computeNavigation` n'a pas besoin de reproduire.
- Le sibling React Native calcule aussi `navigation.instructions` (texte des instructions turn-by-turn) et les transmet côté natif, mais ne les affiche nulle part (`console.log` seulement) — une évolution possible ici serait de les remonter et de les lister dans le bottom sheet, non fait pour rester une démonstration minimale du tracé visuel.
