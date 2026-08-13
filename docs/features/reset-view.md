# Réinitialisation de la vue

## Description

Ajoute un bouton natif « Reset view » qui recentre la caméra sur la venue via `view.goToGlobal()`. Réutilise le pont natif→JS (`window.MapBridge` + `WKWebView.evaluateJavaScript`) introduit par la feature `occupancy-simulated` — aucun nouveau canal de communication n'a été nécessaire, seulement une nouvelle commande sur le pont existant.

Contrairement à `updateOccupancy`, cette commande ne prend aucun argument : elle appelle simplement `view.goToGlobal()`, exposé par la `view` retournée par `visioOne.createView(container, venue)`.

## Step by step

1. **Conserver la `view` retournée par `createView`** (`VisioOneMeet/WebContent/map.html`) — jusqu'ici seule `venue` était hissée en variable de module ; `view` ne l'était pas :
   ```js
   var venue = null;
   var view = null;

   window.MapBridge = {
     goToGlobal: function () {
       if (view) view.goToGlobal();
     },
     updateOccupancy: function (occupancy) { /* inchangé */ },
   };

   visioOne.loadVenue({ hash: '...' }, container)
     .then(function (v) {
       venue = v;
       return visioOne.createView(container, venue);
     })
     .then(function (v) {
       view = v;
     })
     .catch(function (error) {
       visioOne.showError(error, container);
     });
   ```
2. **Ajouter la méthode côté Swift** (`VisioOneMeet/VisioOneBridge.swift`), à côté de `updateOccupancy`, sur la même classe `VisioOneBridge` :
   ```swift
   func goToGlobal() {
       webView?.evaluateJavaScript("window.MapBridge.goToGlobal()") { _, error in
           if let error {
               print("VisioOneBridge: goToGlobal failed: \(error.localizedDescription)")
           }
       }
   }
   ```
3. **Ajouter le bouton dans `FeatureOverlays.swift`** (`ResetViewOverlay`), positionné en haut à droite (`top-trailing`), toujours visible, au-dessus de la carte :
   ```swift
   struct ResetViewOverlay: View {
       @ObservedObject var bridge: VisioOneBridge

       var body: some View {
           VStack {
               HStack {
                   Spacer()
                   Button {
                       bridge.goToGlobal()
                   } label: {
                       Text(Feature.resetView.title)
                   }
                   .buttonStyle(.borderedProminent)
                   .padding()
               }
               Spacer()
           }
       }
   }
   ```
   `FeatureMapView.swift` choisit cet overlay quand `feature == .resetView` et possède la `MapWebView` + le `VisioOneBridge` pour cet écran dédié (voir `docs/features/README.md` du hub pour le pattern « un écran par feature »).

## Points d'attention

- **Aucun risque de cycle de rétention ici** : cette feature n'ajoute pas de `WKScriptMessageHandler` (pas de canal JS→natif), seulement une commande native→JS supplémentaire sur le pont `VisioOneBridge` existant, qui garde déjà sa référence `weak` vers le `WKWebView`.
- **`view` n'est non-`nil` qu'une fois la promesse de `createView` résolue.** Appeler `goToGlobal` avant ce moment (ex. bouton tapé pendant le chargement initial de la carte) est un no-op silencieux côté JS — pas d'erreur, la caméra ne bouge simplement pas. Ce repo n'a pas (encore) de machine à états loading/ready/error pour désactiver le bouton pendant le chargement.
- Le bouton chevauche visuellement la barre de recherche native du SDK (élément d'UI du SDK lui-même, pas de ce bridge) — à ajuster si besoin en fonction du layout réel de la carte utilisée.

## Pour aller plus loin

- Ce pont (`window.MapBridge` + `evaluateJavaScript`) est désormais le point d'ancrage pour les prochains fondamentaux encore ❌ sur cette plateforme (aller à un POI, changer d'étage, calculer un itinéraire) — voir le `ROADMAP.md` du hub (`VisioOneHub`).
