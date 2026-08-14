# Position simulée

## Description

Anime une position simulée (avec son cercle de précision) qui se déplace en va-et-vient entre deux POI, via `view.injectTrackedPosition(positionTrackerOptions)` du SDK. Il n'y a pas de vrai positionnement indoor derrière : une `Task` Swift interpole linéairement entre les deux points toutes les 150 ms et pousse chaque position intermédiaire au pont, en lieu et place d'un flux BLE/Wi-Fi/UWB réel — même logique que `occupancy-simulated` (boucle de simulation côté app), appliquée ici à une position plutôt qu'à une couleur.

Le bottom sheet expose deux champs **Origin POI ID** / **Destination POI ID** (même UX que `goto-poi`/`compute-navigation`), un `Slider` pour le rayon du cercle de précision (1–20 m, défaut 5 m) et un bouton bascule **Simulate position** / **Stop simulated position** (même pattern Start/Stop que `occupancy-simulated`).

Réutilise le pont natif→JS existant (`window.MapBridge` + `VisioOneBridge.evaluateJavaScript`) : deux nouvelles méthodes natif→JS (`injectTrackedPosition`, `stopTrackedPosition`), plus une troisième (`resolvePoiPosition`) qui sert à résoudre un ID de POI en position WGS84 — celle-ci est particulière : elle ne pousse rien via `WKScriptMessageHandler`, elle est lue directement depuis la valeur de retour de `evaluateJavaScript` (voir "Points d'attention").

## Step by step

1. **Ajouter les trois commandes côté JS** (`VisioOneMeet/WebContent/map.html`), dans `window.MapBridge` :
   ```js
   resolvePoiPosition: function (poiId) {
     if (!venue) return null;
     var poi = venue.pois.find(function (p) { return p.id === poiId; });
     if (!poi) return null;
     var position =
       (poi.markers && poi.markers[0] && poi.markers[0].position) ||
       (poi.labels && poi.labels[0] && poi.labels[0].position) ||
       (poi.images && poi.images[0] && poi.images[0].position);
     if (!position) return null;
     return { latitude: position.latitude, longitude: position.longitude };
   },
   injectTrackedPosition: function (latitude, longitude, precisionCircleRadius) {
     if (!view) return;
     view.allowTracking = true;
     view.injectTrackedPosition({
       position: { latitude: latitude, longitude: longitude },
       precisionCircleRadius: precisionCircleRadius,
     });
   },
   stopTrackedPosition: function () {
     if (!view) return;
     view.allowTracking = false;
   },
   ```
2. **Ajouter les méthodes natif→JS correspondantes** (`VisioOneMeet/VisioOneBridge.swift`) :
   ```swift
   struct GeoPosition: Equatable {
       let latitude: Double
       let longitude: Double
   }

   func resolvePoiPosition(_ poiId: String) async -> GeoPosition? {
       guard let webView else { return nil }
       guard let data = try? JSONSerialization.data(withJSONObject: poiId, options: [.fragmentsAllowed]),
             let json = String(data: data, encoding: .utf8) else { return nil }
       return await withCheckedContinuation { continuation in
           webView.evaluateJavaScript("window.MapBridge.resolvePoiPosition(\(json))") { result, error in
               guard error == nil,
                     let payload = result as? [String: Any],
                     let latitude = payload["latitude"] as? Double,
                     let longitude = payload["longitude"] as? Double else {
                   continuation.resume(returning: nil)
                   return
               }
               continuation.resume(returning: GeoPosition(latitude: latitude, longitude: longitude))
           }
       }
   }

   func injectTrackedPosition(latitude: Double, longitude: Double, precisionCircleRadius: Double) {
       webView?.evaluateJavaScript(
           "window.MapBridge.injectTrackedPosition(\(latitude), \(longitude), \(precisionCircleRadius))"
       )
   }

   func stopTrackedPosition() {
       webView?.evaluateJavaScript("window.MapBridge.stopTrackedPosition()")
   }
   ```
   `latitude`/`longitude`/`precisionCircleRadius` sont interpolés directement (pas de `JSONSerialization`) car ce sont des `Double` calculés côté Swift, jamais du texte utilisateur — même règle que le booléen de `setUIPartVisible`.
3. **Overlay dédié** (`SimulatedPositionOverlay` dans `VisioOneMeet/FeatureOverlays.swift`) : deux `TextField` (Origin/Destination POI ID), un `Slider` pour le rayon, un message d'erreur inline si l'une des deux résolutions échoue, et un bouton bascule dont l'action `Task` :
   - résout les deux positions en parallèle (`async let originPosition = bridge.resolvePoiPosition(origin)` / idem pour la destination) ;
   - si l'une des deux est `nil`, affiche l'erreur et s'arrête (pas de tracking démarré) ;
   - sinon boucle `while !Task.isCancelled`, interpolant linéairement entre les deux points (pas de progression de 2 % par tick, ~150 ms/tick, va-et-vient en inversant le sens à chaque extrémité) et appelant `bridge.injectTrackedPosition` à chaque itération avec le rayon **courant** (lu depuis le `@State` à chaque tick, donc le `Slider` peut être bougé pendant que la simulation tourne sans redémarrage).
   - `Stop` annule la `Task` et appelle `bridge.stopTrackedPosition()`.
4. **Enregistrer la feature** dans `Feature.swift` (`case simulatedPosition`, slug `simulated-position`), dans le `switch` de `FeatureMapView.swift` (`case .simulatedPosition: SimulatedPositionOverlay(bridge: bridge)`), et dans `Localizable.xcstrings` (`feature.simulated_position.title` / `.description`, EN + FR).

## Points d'attention

- **`view.injectTrackedPosition` exige `view.allowTracking = true` au préalable**, sinon le SDK lève une exception. Plutôt que d'exposer une étape "activer le tracking" séparée dans le pont, `injectTrackedPosition` côté JS met `allowTracking = true` à **chaque** appel — idempotent et sans risque, ça évite un ordre d'appel à respecter côté Swift.
- **Pas de méthode "stop" dédiée** : le SDK n'offre que `view.allowTracking = false` pour retirer le marqueur + cercle de précision de la carte. C'est ce que fait `stopTrackedPosition`, et c'est aussi ce mécanisme qui nettoie l'affichage si l'utilisateur quitte l'écran (le `WKWebView` est détruit avec toute la carte).
- **Les POI n'ont pas de champ lat/lng direct** : la position vient de `poi.markers[0].position`, `poi.labels[0].position` ou `poi.images[0].position` (premier disponible, dans cet ordre) — jamais d'un champ `poi.position` qui n'existe pas. Si aucun des trois n'existe, ou si l'ID ne correspond à aucun POI, `resolvePoiPosition` renvoie `null`, traité côté Swift comme "POI not found" (même message d'erreur dans les deux cas, indissociables pour l'appelant).
- **`resolvePoiPosition` ne suit pas le pattern JS→natif habituel** (`sendToNative` + `WKScriptMessageHandler`, utilisé par `poi-click`/`floor-selector` pour des événements SDK asynchrones) : c'est une lecture synchrone, sans effet de bord, donc le retour direct de `evaluateJavaScript(_:completionHandler:)` (déjà disponible, simplement ignoré par les autres méthodes du pont) suffit — pas besoin d'un canal de messages avec corrélation de requête/réponse pour un aller-retour aussi simple.
- **C'est une position simulée pilotée par l'app, pas un vrai positionnement indoor** : aucune donnée BLE/Wi-Fi/UWB n'entre en jeu, seulement une interpolation linéaire entre deux points connus à l'avance. Pour un cas client réel, la boucle de simulation serait remplacée par un abonnement au vrai flux de positionnement, sans toucher au pont (`injectTrackedPosition`/`stopTrackedPosition` restent valables tels quels).
- **Le rayon ne s'applique qu'au prochain tick** : bouger le `Slider` pendant que la simulation tourne change la valeur lue à la prochaine itération de la boucle (~150 ms plus tard), pas immédiatement sur le cercle déjà affiché — pas de redémarrage nécessaire, mais un léger délai est normal.
- **La simulation continue si le sheet est fermé** : comme `occupancy-simulated`, la `Task` vit indépendamment de l'overlay qui l'a créée — seul `Stop` ou la sortie de l'écran (qui détruit le `WKWebView`) l'arrête. Rouvrir le sheet puis appuyer à nouveau sur `Simulate position` démarre une seconde boucle concurrente plutôt que de reprendre la première (limitation déjà acceptée sur `occupancy-simulated`, pas résolue ici non plus).

## Pour aller plus loin

- Voir `docs/features/occupancy-simulated.md` pour le même choix d'architecture (boucle de simulation `Task` côté Swift, pas de vrai capteur) appliqué à une couleur de surface plutôt qu'à une position.
- Le SDK expose aussi `view.updatePositionTrackerGraphicOptions({ color, opacity })` pour personnaliser l'apparence du marqueur/cercle — non démontré ici pour rester une démonstration minimale de `injectTrackedPosition`/`allowTracking`.
- Version "vrai positionnement" : voir le `ROADMAP.md` du hub (`VisioOneHub`), hors scope tant qu'aucune source de positionnement indoor réelle (BLE/Wi-Fi/UWB) n'est disponible pour ces démos.
