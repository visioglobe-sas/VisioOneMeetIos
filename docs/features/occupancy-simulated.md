# Occupation temps réel (données simulées)

## Description

Colore dynamiquement la surface d'un POI pour refléter un statut d'occupation (libre / bientôt occupé / occupé), via une nouvelle commande `updateOccupancy` ajoutée au pont natif→JS — **qui n'existait pas du tout avant cette feature** sur cette plateforme (aucun pont, dans aucune direction).

Il n'y a pas de vrai capteur derrière : une `Task` Swift fait tourner la couleur toutes les 2,5 secondes, en lieu et place d'un flux IoT réel.

## Step by step

1. **Ajouter la commande côté JS** (`VisioOneMeet/WebContent/map.html`) — la `venue` doit être hissée en variable accessible au script (elle n'était utilisée que dans la promesse `.then`) :
   ```js
   var venue = null;

   window.MapBridge = {
     updateOccupancy: function (occupancy) {
       if (!venue) return;
       occupancy.forEach(function (entry) {
         var poi = venue.pois.find(function (p) { return p.id === entry.planId; });
         if (!poi) return;
         poi.surfaces.forEach(function (surface) {
           venue.updateSurface(surface, { color: entry.color });
         });
       });
     },
   };

   visioOne.loadVenue({ hash: '...' }, container).then(function (v) {
     venue = v; // au lieu de passer directement à createView
     return visioOne.createView(container, venue);
   });
   ```
2. **Créer un pont Swift dédié** (`VisioOneMeet/VisioOneBridge.swift`), une classe `ObservableObject` détenant une référence `weak` vers le `WKWebView` :
   ```swift
   final class VisioOneBridge: ObservableObject {
       weak var webView: WKWebView?

       func updateOccupancy(planId: String, color: String?) {
           guard let webView else { return }
           let entry: [String: Any] = ["planId": planId, "color": color ?? NSNull()]
           guard let data = try? JSONSerialization.data(withJSONObject: [entry]),
                 let json = String(data: data, encoding: .utf8) else { return }
           webView.evaluateJavaScript("window.MapBridge.updateOccupancy(\(json))")
       }
   }
   ```
3. **Faire accepter le bridge à `MapWebView`** (`struct MapWebView: UIViewRepresentable`) et l'attacher une fois le `WKWebView` créé : `bridge.webView = webView` dans `makeUIView`.
4. **Piloter la boucle depuis la vue SwiftUI** (`ContentView.swift`), avec `@StateObject private var bridge = VisioOneBridge()` possédé par la vue, et une `Task` annulable stockée en `@State` :
   ```swift
   occupancySimulationTask = Task {
       var colorIndex = 0
       bridge.updateOccupancy(planId: targetPlaceId, color: occupancyColors[colorIndex])
       while !Task.isCancelled {
           try? await Task.sleep(nanoseconds: 2_500_000_000)
           guard !Task.isCancelled else { break }
           colorIndex = (colorIndex + 1) % occupancyColors.count
           bridge.updateOccupancy(planId: targetPlaceId, color: occupancyColors[colorIndex])
       }
       bridge.updateOccupancy(planId: targetPlaceId, color: nil) // reset
   }
   ```
   Arrêter la simulation appelle `occupancySimulationTask?.cancel()` — le code après la boucle `while` s'exécute quand même une fois la tâche annulée, ce qui garantit la réinitialisation de la couleur.
5. **Régénérer le projet Xcode après avoir ajouté `VisioOneBridge.swift`** : `xcodegen generate` (le fichier est repris automatiquement par le glob `sources: VisioOneMeet` de `project.yml`, mais Xcode ne le voit qu'après régénération).

## Points d'attention

- **`JSONSerialization.data(withJSONObject:)` refuse un `nil` Swift brut** dans un dictionnaire/tableau — utiliser `NSNull()` explicitement pour encoder un `color` absent en `null` JSON, sinon la sérialisation échoue silencieusement (`try?` renvoie `nil`, la commande JS n'est jamais envoyée).
- **`weak var webView`** : le bridge ne doit pas garder une référence forte vers le `WKWebView`, qui est possédé par le cycle de vie SwiftUI/`UIViewRepresentable` — une référence forte créerait un cycle de rétention potentiel.
- **Aucun canal JS → natif n'existe encore** (pas de `WKScriptMessageHandler`) — cette feature n'en a pas besoin (`updateOccupancy` est purement natif → JS), mais toute feature future qui a besoin d'un retour du SDK (ex. `poiclick`) devra l'ajouter, en suivant le pattern déjà documenté dans `docs/APP_SDK_COMMUNICATION.md` (un objet-pont `window.MapBridge` côté JS existe déjà comme point d'ancrage).
- **`planId` doit être un vrai ID de POI de la carte chargée** — `venue.pois.find(...)` échoue silencieusement côté JS si l'ID ne correspond à rien.
- Ceci démontre la **mécanique** de mise à jour temps réel, pas une vraie intégration IoT — pour un cas client réel, remplacer la `Task`/boucle simulée par un abonnement à la vraie source (websocket, polling d'API) sans toucher au pont ni au SDK.

## Pour aller plus loin

- Ce pont natif→JS (`window.MapBridge` + `evaluateJavaScript`) est le point de départ pour câbler les autres fondamentaux encore ❌ sur cette plateforme (aller à un POI, changer d'étage, itinéraire) — voir `ROADMAP.md` du hub (`VisioOneHub`), Phase 0.
- Version "vrai capteur" : voir le `ROADMAP.md` du hub, feature "Suivi d'actifs connectés (IoT)" — hors scope tant qu'aucun flux IoT réel n'est disponible.
