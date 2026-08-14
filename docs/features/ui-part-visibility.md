# Masquage sélectif de l'UI

## Description

Affiche/masque individuellement chacune des 5 parties de l'UI par défaut du SDK, via `view.setUIPartVisible(uiPart, isVisible)`. Le bottom sheet expose 5 `Toggle` SwiftUI, un par valeur du type SDK `UIPart` (`floorSelector`, `navigation`, `poiDetails`, `search`, `userTracking`), tous activés par défaut — l'état par défaut du SDK lui-même — et dont chaque bascule appelle immédiatement le pont natif→JS pour un effet visible sur la carte derrière le sheet.

Réutilise le pont natif→JS existant (`window.MapBridge` + `VisioOneBridge.evaluateJavaScript`, introduit par `occupancy-simulated`) : une nouvelle méthode natif→JS (`setUIPartVisible`), aucun nouveau canal JS→natif — l'état des 5 toggles est purement local au sheet (`@State`), le SDK n'a pas besoin de renvoyer quoi que ce soit puisque cette démo ne fait qu'écrire, jamais lire, la visibilité (voir "Points d'attention" pour la nuance sur `isUIPartVisible`).

## Step by step

1. **Ajouter la commande côté JS** (`VisioOneMeet/WebContent/map.html`), dans `window.MapBridge` :
   ```js
   setUIPartVisible: function (uiPart, isVisible) {
     if (!view) return;
     view.setUIPartVisible(uiPart, isVisible);
   },
   ```
2. **Ajouter la méthode natif→JS correspondante** (`VisioOneMeet/VisioOneBridge.swift`), même style que `goToFloor`/`goToBuilding` (un seul argument string, JSON-encodé via `.fragmentsAllowed`) plus un booléen interpolé directement (`true`/`false` ne posent aucun risque d'injection) :
   ```swift
   func setUIPartVisible(_ uiPart: String, isVisible: Bool) {
       guard let webView else { return }

       guard let data = try? JSONSerialization.data(withJSONObject: uiPart, options: [.fragmentsAllowed]),
             let json = String(data: data, encoding: .utf8) else { return }

       webView.evaluateJavaScript("window.MapBridge.setUIPartVisible(\(json), \(isVisible))") { _, error in
           if let error {
               print("VisioOneBridge: setUIPartVisible failed: \(error.localizedDescription)")
           }
       }
   }
   ```
3. **Modéliser les 5 valeurs** (`MapUIPart` dans `VisioOneMeet/FeatureOverlays.swift`) : un `enum` Swift dont les `rawValue` reproduisent exactement les 5 chaînes du type SDK `UIPart`, plus un titre localisé par cas :
   ```swift
   enum MapUIPart: String, CaseIterable, Identifiable {
       case floorSelector
       case navigation
       case poiDetails
       case search
       case userTracking

       var id: String { rawValue }
       var title: LocalizedStringResource { /* une clé par cas */ }
   }
   ```
4. **Overlay dédié** (`UIPartVisibilityOverlay` dans `VisioOneMeet/FeatureOverlays.swift`) : une `List` de 5 `Toggle`, un par `MapUIPart.allCases`, état local (`@State private var visibility: [MapUIPart: Bool]`, tous `true` à l'initialisation) — au changement d'un toggle, `bridge.setUIPartVisible(part.rawValue, isVisible: newValue)` est appelé immédiatement, dans le bottom sheet ouvert par le FAB par défaut de `FeatureMapView` — pas de logique spéciale requise, comme `floor-selector`/`compute-navigation`.
5. **Enregistrer la feature** dans `Feature.swift` (`case uiPartVisibility`, slug `ui-part-visibility`), dans le `switch` de `FeatureMapView.swift` (`case .uiPartVisibility: UIPartVisibilityOverlay(bridge: bridge)`), et dans `Localizable.xcstrings` (`feature.ui_part_visibility.title` / `.description` pour le menu, plus une clé `feature.ui_part_visibility.part.*` par toggle, EN + FR).

## Points d'attention

- **N'appeler `setUIPartVisible` qu'une fois la vue/venue chargée** : comme tout le reste du pont, `window.MapBridge.setUIPartVisible` est un no-op silencieux tant que `view` n'existe pas encore (`if (!view) return;`) — ici ce n'est de toute façon jamais un problème en pratique puisque le FAB qui ouvre le sheet n'apparaît lui-même qu'une fois `bridge.loadState == .ready` (voir `FeatureMapView.swift`), donc `view` est nécessairement déjà résolu quand un toggle peut être basculé.
- **Les 5 valeurs de `uiPart` sont exactes et sensibles à la casse** : `floorSelector`, `navigation`, `poiDetails`, `search`, `userTracking` — aucune autre valeur n'existe (voir le type `UIPart` dans le SDK). Une faute de casse (`poidetails`, `Navigation`, etc.) n'est pas rejetée avec une erreur explicite : `view.setUIPartVisible` l'ignore silencieusement côté SDK, exactement comme un Place ID ou un floor ID inconnu ailleurs dans ce pont. D'où le choix d'un `enum` Swift (`MapUIPart`) plutôt que des chaînes libres dans l'overlay, pour éliminer la faute de frappe à la source plutôt que de la déboguer sur la carte.
- **Masquer `search` ou `navigation` retire le seul déclencheur SDK de ces flux pour l'utilisateur final** — contrairement à `floorSelector`/`poiDetails`/`userTracking`, dont la disparition n'empêche rien d'autre de fonctionner, désactiver ces deux-là dans la démo coupe la seule façon de déclencher une recherche ou d'afficher les instructions de navigation par défaut du SDK (cette démo n'a pas d'équivalent natif à ces deux widgets). Dans le sheet de cette feature, on peut toujours les rebasculer sur ON à tout moment pour les faire réapparaître — pensez-y avant de conclure qu'une fonctionnalité a disparu en testant cette démo.
- **Pas de lecture de l'état initial via `isUIPartVisible`** : les 5 toggles partent d'un état local Swift toujours à `true` (jamais interrogé depuis le SDK au chargement) plutôt que d'appeler `view.isUIPartVisible(part)` pour chaque partie après `createView` — un raccourci valable ici puisque `true` est justement la valeur par défaut documentée du SDK pour les 5 parties, mais qui suppose que rien d'autre (une autre feature, un futur changement du SDK) n'a déjà modifié cette visibilité avant l'ouverture du sheet. Un client voulant un état garanti synchronisé lirait `isUIPartVisible` au moment de construire l'overlay plutôt que de supposer `true`.

## Pour aller plus loin

- Voir `docs/features/floor-selector.md`, qui mentionne déjà `view.setUIPartVisible('floorSelector', false)` comme moyen de masquer le sélecteur d'étage par défaut du SDK au profit d'un composant natif — cette feature généralise ce même appel aux 4 autres parties de l'UI, sans remplacer aucune d'entre elles par un équivalent natif (masquage seul, pas de composant de substitution).
- Le SDK expose aussi `view.showUI` (booléen global masquant/affichant toute l'UI d'un coup) — non démontré ici pour rester une démonstration minimale du contrôle partie par partie via `setUIPartVisible`/`UIPart`.
