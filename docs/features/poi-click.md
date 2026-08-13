# Réagir au clic sur un POI

## Description

Affiche un panneau natif (nom + ID) quand l'utilisateur tape un POI sur la carte, en s'abonnant à l'événement `poiclick` du SDK (`view.addEventListener('poiclick', ...)`) et en le relayant au natif via le canal JS → natif existant (`sendToNative`, introduit par `loading-state`).

Contrairement aux autres features de ce repo, le déclencheur n'est pas un FAB natif mais l'événement SDK lui-même : le panneau s'ouvre automatiquement dès qu'un POI est tapé sur la carte, sans action native préalable.

## Step by step

1. **S'abonner à `poiclick` côté JS** (`VisioOneMeet/WebContent/map.html`), une fois `view` résolu par `createView`, et relayer l'ID + le libellé du premier POI touché via le helper `sendToNative` déjà utilisé par `ready`/`error` :
   ```js
   .then(function (v) {
     view = v;

     view.addEventListener('poiclick', function (event) {
       var poi = event.pois && event.pois[0];
       if (!poi) return;
       sendToNative('poiSelected', {
         id: poi.id,
         name: poi.labels && poi.labels.length ? poi.labels[0].text : null,
       });
     });

     sendToNative('ready');
   })
   ```
   `event.pois` est le tableau (potentiellement vide) des POIs sous le point tapé — seul le premier (le plus proche de la caméra) est utilisé ici. `poi.labels[0].text` est le libellé résolu par le SDK pour la locale courante ; un POI sans libellé donne un tableau `labels` vide, d'où le garde `poi.labels && poi.labels.length`.

2. **Étendre `VisioOneBridge`** (`VisioOneMeet/VisioOneBridge.swift`) avec un nouveau type publié et un nouveau `case` dans le `switch` JS → natif déjà en place (ajouté par `loading-state`) :
   ```swift
   struct TappedPOI: Equatable {
       let id: String
       let name: String?
   }

   @Published private(set) var tappedPOI: TappedPOI?

   func clearTappedPOI() {
       tappedPOI = nil
   }

   // dans userContentController(_:didReceive:) :
   case "poiSelected":
       guard let payload = body["message"] as? [String: Any],
             let id = payload["id"] as? String else { return }
       tappedPOI = TappedPOI(id: id, name: payload["name"] as? String)
   ```
   `body["message"]` est ici un `NSDictionary` (`{id, name}`) plutôt qu'une simple `String` comme pour `error` — `sendToNative(type, message)` n'a pas besoin de changer de signature, `message` accepte déjà n'importe quelle valeur JSON-compatible.

3. **Présenter automatiquement le sheet existant** plutôt que de le faire dépendre d'un FAB (`VisioOneMeet/FeatureMapView.swift`) :
   ```swift
   .sheet(isPresented: $isControlPresented, onDismiss: {
       if feature == .poiClick { bridge.clearTappedPOI() }
   }) {
       overlay
           .background(Color(.systemBackground))
           .presentationDetents([.medium])
           .presentationDragIndicator(.visible)
   }
   .onChange(of: bridge.tappedPOI) { newValue in
       guard feature == .poiClick else { return }
       isControlPresented = newValue != nil
   }
   ```
   Le FAB est masqué pour cette feature (rien à ouvrir manuellement) et remplacé par une pastille d'indication (« Tap a POI on the map ») tant qu'aucun POI n'a encore été tapé, pour la découvrabilité.

4. **Contenu du panneau** (`PoiClickOverlay` dans `VisioOneMeet/FeatureOverlays.swift`) : simple lecture de `bridge.tappedPOI` (nom + ID), avec un état vide explicite si jamais le sheet s'ouvrait sans donnée (ne devrait pas arriver via ce flux, mais garde défensive).

5. **Enregistrer la feature** dans `Feature.swift` (`case poiClick`, slug `poi-click`) et dans `Localizable.xcstrings` (`feature.poi_click.title` / `.description`, EN + FR).

6. **Régénérer le projet Xcode** après l'ajout des nouveaux cas : `xcodegen generate`.

## Points d'attention

- **Le canal JS → natif était déjà en place** (`WKScriptMessageHandler` sur `VisioOneBridge`, ajouté par `loading-state`) — cette feature n'ajoute qu'un nouveau `case` au `switch` existant, pas un second bridge. C'était exactement la feature anticipée par `docs/features/occupancy-simulated.md` (« toute feature future qui a besoin d'un retour du SDK (ex. `poiclick`) devra [ajouter ce canal] »).
- **`sendToNative`'s `message` n'est pas restreint à une `String`** : il suffit de lui passer un objet JS ; côté Swift, `body["message"] as? [String: Any]` le récupère tel quel (`WKScriptMessage.body` accepte tout type property-list — `NSDictionary` inclus).
- **`event.pois` peut être vide** (tap sur du vide, sur une surface sans POI, etc.) — toujours garder `event.pois[0]` derrière un test de présence avant de relayer quoi que ce soit, sinon `poi.id`/`poi.labels` plantent côté JS sur `undefined`.
- **`poi.labels` peut aussi être vide** même quand le POI existe (POI sans libellé dans la locale courante) — `name` est alors envoyé comme `null`, et le panneau natif affiche un texte de repli plutôt qu'une valeur vide.
- **Pas de FAB pour cette feature** : contrairement aux autres écrans, le déclencheur est l'événement SDK lui-même. `FeatureMapView` masque le FAB et affiche une pastille d'indication tant que `bridge.tappedPOI == nil`, pour que l'utilisateur sache qu'il doit taper un POI plutôt que chercher un bouton absent.
- **Réinitialisation à la fermeture** (`bridge.clearTappedPOI()` dans `onDismiss`) : sans ça, retaper le **même** POI ne redéclencherait pas `.onChange` (la valeur ne change pas), et le sheet ne se réouvrirait pas après une première fermeture.
- Le panneau ne remplace pas le `poiDetails` du SDK lui-même (toujours visible sur la carte, propre au SDK) — les deux coexistent ; masquer celui du SDK (`view.setUIPartVisible('poiDetails', false)`) est une option si on veut que la version native soit la seule source de vérité, non retenue ici pour rester une démonstration minimale du bridge.

## Pour aller plus loin

- Le même canal JS → natif (`sendToNative` + `case` dans `VisioOneBridge`) est réutilisable pour tout autre événement SDK nécessitant une réaction native (`selectedpoischange`, `currentfloorchanged`, `navigationstarted`, …) — voir la liste complète dans `EventType.d.ts` du SDK et `docs/APP_SDK_COMMUNICATION.md` §2.3.
- Voir le `ROADMAP.md` du hub (`VisioOneHub`) pour la suite des fondamentaux encore ❌ sur cette plateforme.
