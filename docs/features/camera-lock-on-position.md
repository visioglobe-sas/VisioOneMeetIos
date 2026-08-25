# Verrouillage caméra sur la position

## Description

Ajoute une bascule **Recenter camera on position** ("recentrer sur moi", comme une app GPS) qui verrouille le focus de la caméra sur la position simulée actuellement suivie, via `view.lockCameraPositionOnTracking` du SDK. Cette feature dépend entièrement de `simulated-position` (voir `docs/features/simulated-position.md`) : sans une position suivie qui bouge, verrouiller la caméra dessus n'a aucun effet visible — l'écran de cette feature reprend donc à l'identique les champs **Origin POI ID** / **Destination POI ID**, le `Slider` de rayon de précision et le bouton **Simulate position** / **Stop simulated position**, puis ajoute la nouvelle bascule en dessous.

Plutôt que de dupliquer la boucle de simulation (~60 lignes de `Task` Swift, voir `docs/features/simulated-position.md`) entre les deux écrans, elle a été extraite dans une classe partagée `PositionTrackingController` (`ObservableObject`), et l'UI Origin/Destination/rayon/bouton associée dans une vue partagée `PositionTrackingControls` — les deux dans `VisioOneMeet/FeatureOverlays.swift`. `SimulatedPositionOverlay` (inchangée dans son comportement) et la nouvelle `CameraLockOnPositionOverlay` instancient chacune leur propre `PositionTrackingController`, et n'affichent que `PositionTrackingControls(controller:)` — la seconde ajoute juste la bascule de verrouillage caméra en plus.

Réutilise le pont natif→JS existant (`window.MapBridge` + `VisioOneBridge.evaluateJavaScript`) : une seule nouvelle méthode natif→JS, `setCameraLockOnPosition(locked)`, aucun nouveau canal JS→natif.

## Step by step

1. **Ajouter la commande côté JS** (`VisioOneMeet/WebContent/map.html`), dans `window.MapBridge` :
   ```js
   setCameraLockOnPosition: function (locked) {
     if (!view) return;
     view.lockCameraPositionOnTracking = locked;
   },
   ```
2. **Ajouter la méthode natif→JS correspondante** (`VisioOneMeet/VisioOneBridge.swift`), même style que `stopTrackedPosition`/`setUIPartVisible` (un booléen interpolé directement, jamais de texte utilisateur donc pas de `JSONSerialization`) :
   ```swift
   func setCameraLockOnPosition(_ locked: Bool) {
       webView?.evaluateJavaScript("window.MapBridge.setCameraLockOnPosition(\(locked))") { _, error in
           if let error {
               print("VisioOneBridge: setCameraLockOnPosition failed: \(error.localizedDescription)")
           }
       }
   }
   ```
3. **Extraire la boucle de simulation partagée** (`PositionTrackingController` dans `VisioOneMeet/FeatureOverlays.swift`) : reprend tel quel le contenu de l'ancien `SimulatedPositionOverlay` (résolution des deux POI via `bridge.resolvePoiPosition`, puis boucle `while !Task.isCancelled` d'interpolation linéaire va-et-vient, `injectTrackedPosition` toutes les ~150 ms), exposé comme un `ObservableObject` avec `originPlaceId`/`destinationPlaceId`/`precisionCircleRadius`/`isSimulating`/`errorMessage` publiés, et `start()`/`stop()`/`toggle()`. Puis extraire l'UI associée (`PositionTrackingControls`, les deux `TextField` + `Slider` + message d'erreur + bouton bascule) dans une `View` séparée prenant ce contrôleur en paramètre. `SimulatedPositionOverlay` est mise à jour pour instancier un `PositionTrackingController` et afficher juste `PositionTrackingControls(controller:)` — son comportement observable ne change pas.
4. **Overlay dédié** (`CameraLockOnPositionOverlay` dans `VisioOneMeet/FeatureOverlays.swift`) : affiche `PositionTrackingControls(controller:)`, un `Divider`, puis un `Toggle` **Recenter camera on position** :
   - désactivé (`.disabled(!controller.isSimulating)`) tant qu'aucune simulation ne tourne ;
   - au changement, appelle immédiatement `bridge.setCameraLockOnPosition(newValue)` ;
   - un `.onChange(of: controller.isSimulating)` réinitialise la bascule à `false` (+ rappel `bridge.setCameraLockOnPosition(false)`) dès que `isSimulating` repasse à `false` — que ce soit parce que l'utilisateur a appuyé sur **Stop simulated position**, ou parce que la résolution d'un des deux POI a échoué ("POI not found") : dans les deux cas `PositionTrackingController` remet déjà `isSimulating` à `false`, donc ce seul `onChange` couvre les deux déclencheurs sans code dupliqué.
5. **Enregistrer la feature** dans `Feature.swift` (`case cameraLockOnPosition`, slug `camera-lock-on-position`), dans le `switch` de `FeatureMapView.swift` (`case .cameraLockOnPosition: CameraLockOnPositionOverlay(bridge: bridge)`), et dans `Localizable.xcstrings` (`feature.camera_lock_on_position.title` / `.description`, EN + FR) — même mécanisme que `simulated-position`, la liste de features de `ContentView` est générée depuis `Feature.allCases` donc rien d'autre à toucher.

## Points d'attention

- **`lockCameraPositionOnTracking` n'a d'effet visible qu'une fois `view.allowTracking` déjà à `true`** — c'est-à-dire une fois qu'une position est effectivement en cours de simulation/tracking (voir `simulated-position`). L'activer avant est documenté par le SDK comme un no-op silencieux, **pas** une exception (contrairement à `view.injectTrackedPosition`, qui lève si `allowTracking` est `false`) : aucune garde n'est donc nécessaire côté JS ou côté Swift, à la différence de `injectTrackedPosition`.
- **Le SDK expose aussi `lockCameraOrientationOnTracking`** (verrouillage de l'*orientation* de la caméra, nécessitant des données de capteur d'orientation de l'appareil) — volontairement hors scope ici, cette feature ne démontre que le verrouillage de *position*.
- **La bascule est désactivée tant qu'aucune simulation ne tourne** (`!controller.isSimulating`) : verrouiller la caméra sur rien n'a aucun sens ni aucun effet observable. Comme les toggles de `ui-part-visibility`, `.disabled(...)` n'empêche que l'interaction utilisateur — un binding est toujours réglable par du code, mais aucun chemin de cette feature ne le fait tant que la simulation n'est pas active.
- **La bascule se remet à `off` (avec le rappel `setCameraLockOnPosition(false)`) dans deux cas, pas trois** : bouton **Stop** pressé, ou erreur "POI not found" à la résolution — les deux étant unifiés par `PositionTrackingController.isSimulating` retombant à `false`, observé par un seul `onChange`. Le troisième cas mentionné dans la spec de cette feature — quitter l'écran — est couvert différemment : quitter `FeatureMapView` détruit le `WKWebView` entier (voir CLAUDE.md), ce qui jette avec lui l'objet `view` du SDK et donc `lockCameraPositionOnTracking` — exactement le même mécanisme qui nettoie déjà la position suivie elle-même pour `simulated-position` (voir ses "Points d'attention"). Rouvrir l'écran recrée une carte neuve avec `lockCameraPositionOnTracking` à sa valeur par défaut (`false`) ; aucun code Swift dédié à ce troisième cas n'était donc nécessaire.
- **`PositionTrackingController` est un `ObservableObject` par overlay, pas partagé entre `SimulatedPositionOverlay` et `CameraLockOnPositionOverlay`** : chaque écran instancie le sien (`@StateObject`). Ce n'est pas un état partagé entre les deux features — démarrer une simulation dans l'une n'affecte pas l'autre, elles sont juste bâties sur le même bloc de code réutilisable. Cette extraction n'a rien changé au comportement déjà documenté de `simulated-position` (notamment la limitation acceptée : fermer/rouvrir le bottom sheet perd la référence Swift à la `Task` en cours sans l'annuler, voir ses "Points d'attention").
- **Vérification en simulateur iOS** : cet environnement de build n'exposait aucune fenêtre interactive (ni via `System Events`/Accessibility, ni via un outil comme `idb`), donc le pan de caméra réel n'a pas pu être capturé visuellement bout en bout. La UI de l'écran (champs, slider, message d'erreur, bascule) a en revanche été confirmée par capture d'écran (`xcrun simctl io ... screenshot`) sur un build réel installé et lancé sur simulateur, build qui compile et s'exécute sans erreur.

## Pour aller plus loin

- Voir `docs/features/simulated-position.md` pour le détail de la boucle de simulation elle-même (désormais dans `PositionTrackingController`), inchangée par cette feature.
- Le SDK expose aussi `lockCameraOrientationOnTracking` (verrouillage de l'orientation caméra sur les données de capteur d'orientation de l'appareil) — non démontré ici, voir "Points d'attention" ci-dessus.
