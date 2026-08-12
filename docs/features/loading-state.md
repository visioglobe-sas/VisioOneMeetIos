# État de chargement visible dans l'UI native

## Description

Reflète l'état loading/ready/error du SDK dans l'UI SwiftUI (spinner puis overlay d'erreur avec bouton "Réessayer"), plutôt que de laisser l'utilisateur face à une `WKWebView` figée pendant le chargement de `map.html`. S'appuie sur un canal JS → natif ajouté à `VisioOneBridge` (`WKScriptMessageHandler`), qui n'existait pas du tout sur cette plateforme avant cette feature (le seul pont existant, ajouté par `occupancy-simulated`, allait natif → JS).

## Step by step

1. **Faire remonter le cycle de vie côté JS** (`VisioOneMeet/WebContent/map.html`) — poster `{type, message?}` sur `window.webkit.messageHandlers.mapBridge` une fois `createView` résolu, ou dans le `.catch` :
   ```js
   function sendToNative(type, message) {
     var handler = window.webkit && window.webkit.messageHandlers && window.webkit.messageHandlers.mapBridge;
     if (!handler) { console.log('[VisioOne:web]', type, message); return; }
     handler.postMessage({ type: type, message: message });
   }

   visioOne.loadVenue({ hash: '...' }, container)
     .then(function (v) { venue = v; return visioOne.createView(container, venue); })
     .then(function () { sendToNative('ready'); })
     .catch(function (error) {
       visioOne.showError(error, container);
       sendToNative('error', error && error.message ? error.message : String(error));
     });
   ```
2. **Étendre le pont existant** (`VisioOneMeet/VisioOneBridge.swift`) pour qu'il conforme aussi à `WKScriptMessageHandler` et publie l'état — un seul bridge gère les deux directions plutôt que d'en créer un second :
   ```swift
   final class VisioOneBridge: NSObject, WKScriptMessageHandler, ObservableObject {
       static let messageHandlerName = "mapBridge"
       @Published private(set) var loadState: MapLoadState = .loading
       weak var webView: WKWebView?

       func reload() { loadState = .loading; webView?.reload() }

       func userContentController(_ c: WKUserContentController, didReceive message: WKScriptMessage) {
           guard message.name == Self.messageHandlerName,
                 let body = message.body as? [String: Any],
                 let type = body["type"] as? String else { return }
           switch type {
           case "ready": loadState = .ready
           case "error": loadState = .error(body["message"] as? String ?? "Erreur inconnue du SDK VisioOne")
           default: break
           }
       }
   }
   ```
3. **Enregistrer le handler via un proxy faible** — `WKUserContentController.add(_:name:)` retient fortement son handler ; enregistrer `VisioOneBridge` directement créerait un cycle de rétention avec la `WKWebView` :
   ```swift
   final class WeakScriptMessageHandler: NSObject, WKScriptMessageHandler {
       private weak var target: WKScriptMessageHandler?
       init(target: WKScriptMessageHandler) { self.target = target }
       func userContentController(_ c: WKUserContentController, didReceive message: WKScriptMessage) {
           target?.userContentController(c, didReceive: message)
       }
   }
   ```
4. **Câbler `MapWebView`** (`UIViewRepresentable`) : créer un `WKUserContentController`, y ajouter le proxy avant de construire la `WKWebViewConfiguration`, et retirer le handler dans `dismantleUIView` :
   ```swift
   let contentController = WKUserContentController()
   contentController.add(WeakScriptMessageHandler(target: bridge), name: VisioOneBridge.messageHandlerName)
   let configuration = WKWebViewConfiguration()
   configuration.userContentController = contentController
   ```
5. **Afficher l'état dans `ContentView`** — un `switch bridge.loadState` en overlay du `ZStack` existant : `ProgressView` pour `.loading`, le panneau de simulation d'occupation pour `.ready` (masqué tant que la carte n'est pas prête), un panneau avec message + bouton "Réessayer" (`bridge.reload()`) pour `.error`. Les deux overlays `.loading`/`.error` prennent `.frame(maxWidth: .infinity, maxHeight: .infinity)` pour se centrer indépendamment de l'`alignment: .bottom` du `ZStack` parent (hérité du panneau d'occupation).

## Points d'attention

- **`message.body` n'est jamais force-cast** — seuls les types property-list (`NSString`, `NSNumber`, `NSArray`, `NSDictionary`, `NSNull`, `NSDate`) traversent le pont ; toujours `as?` avec repli silencieux (`default: break`) sur un type inattendu.
- **Le proxy faible n'est pas cosmétique** : sans lui, `WKUserContentController` (détenu par la configuration, détenue par la `WKWebView`) retient `VisioOneBridge`, qui retient potentiellement la vue via ses closures/`@Published` — cycle classique de fuite WebKit. Voir `docs/APP_SDK_COMMUNICATION.md` §2.2.
- **`reload()` remet `loadState` à `.loading` avant d'appeler `webView.reload()`** — sinon l'UI resterait bloquée sur l'ancien état (`.error`) jusqu'au prochain message JS, ce qui donnerait l'impression que "Réessayer" n'a rien fait pendant le temps du rechargement.
- **`isInspectable` n'est disponible qu'à partir d'iOS 16.4** alors que `deploymentTarget` est 16.0 — l'activation est gardée par `#available(iOS 16.4, *)` et par `#if DEBUG`, pour ne jamais l'activer en release.
- **Un seul bridge, deux directions** : `updateOccupancy` (natif → JS, ajouté par `occupancy-simulated`) et `loadState` (JS → natif, ajouté ici) vivent tous les deux dans `VisioOneBridge` plutôt que dans deux classes séparées — évite la confusion de deux ponts qui se chevauchent et matche le pattern one-bridge des autres plateformes (Android `MapBridge`, Flutter `VisioOneController`).
- Ce canal JS → natif est réutilisable tel quel pour toute feature future qui a besoin d'un retour du SDK (`poiclick`, changement d'étage, itinéraire) — ajouter un nouveau `case` dans le `switch` de `userContentController(_:didReceive:)`.

## Pour aller plus loin

- Le canal natif → JS (`window.MapBridge` côté `map.html`, `evaluateJavaScript` côté Swift) reste à construire pour les fondamentaux encore ❌ sur cette plateforme (aller à un POI, changer d'étage, itinéraire) — voir `ROADMAP.md` du hub (`VisioOneHub`), Phase 0.
