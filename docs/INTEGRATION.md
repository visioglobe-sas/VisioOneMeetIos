# Intégrer le SDK VisioOne dans une application iOS native

Ce guide explique comment afficher une carte [VisioOne](https://www.npmjs.com/package/@visioglobe/visioone) dans une application iOS native (Swift/SwiftUI), en embarquant le SDK JavaScript dans une `WKWebView`.

VisioOne est un SDK **web** (JS/WebGL) : il n'existe pas de binaire Swift natif. L'intégration native consiste donc à :

1. embarquer le SDK JS et une page HTML hôte dans le bundle de l'application,
2. afficher cette page dans une `WKWebView` plein écran,
3. piloter la carte via l'API JS du SDK (chargement d'un site, navigation, etc.).

Aucune permission système (localisation, caméra…) n'est requise pour un affichage de carte basique.

## Prérequis

- Xcode 15+ (testé avec Xcode 16.2), iOS 16+
- Node.js/npm (uniquement pour récupérer le SDK, aucun build JS n'est nécessaire ensuite)
- Un **hash de carte** valide, obtenu depuis [my.visioglobe.com](https://my.visioglobe.com) (chaîne alphanumérique de 41 caractères, ex. `kd9426d8cb3f1c532f22b5bcbd325c280bd351feb` — la carte doit avoir été "buildée" au préalable)

## 1. Récupérer le SDK

Le SDK est distribué sous forme de package npm :

```bash
npm pack @visioglobe/visioone
tar xzf visioglobe-visioone-*.tgz
```

Le fichier qui nous intéresse est **`package/dist/visioone.umd.cjs`** : un bundle UMD autonome (~5 Mo) qui embarque son propre CSS et ses assets (icônes, animations) en base64. C'est ce fichier qu'on charge tel quel dans une balise `<script>`, sans bundler ni transpilation.

> ⚠️ Ne pas utiliser `dist/visioone.js` (build ESM) tel quel dans une WebView : ce fichier référence des chunks JS chargés dynamiquement via `import()`, ce qui échoue en `file://` sous WebKit (restrictions CORS sur les modules ES en local). Le bundle **UMD** évite ce problème.

## 2. Structure du projet

```
MonApp/
├── MonApp.xcodeproj
└── MonApp/
    ├── MonAppApp.swift
    ├── ContentView.swift
    ├── MapWebView.swift        // wrapper WKWebView
    └── WebContent/             // ⚠️ voir avertissement ci-dessous
        ├── map.html
        └── visioone.umd.cjs
```

> ⚠️ **Ne nommez jamais ce dossier `Resources`.** Un dossier appelé littéralement `Resources` à la racine du bundle applicatif iOS fait échouer l'installation sur le simulateur (et potentiellement sur device), avec une erreur trompeuse :
> ```
> The application's Info.plist does not contain a valid CFBundleVersion.
> ```
> même quand `CFBundleVersion` est bien présent et valide. En cause : CoreSimulator interprète la présence d'un dossier `Resources` comme la structure `Contents/Resources` d'un bundle macOS et échoue à localiser l'`Info.plist` là où il l'attend. Utilisez un autre nom (`WebContent`, `WebAssets`, etc.).

## 3. La page HTML hôte

Créez `WebContent/map.html`. Le SDK, une fois chargé en `<script>` classique (pas `type="module"`), s'expose sur `window.VisioOne` :

```html
<!DOCTYPE html>
<html lang="fr">
<head>
  <meta charset="utf-8" />
  <meta name="viewport" content="width=device-width, initial-scale=1, maximum-scale=1, user-scalable=no, viewport-fit=cover" />
  <title>VisioOne Map</title>
  <style>
    html, body { margin: 0; padding: 0; width: 100%; height: 100%; background: #000; overflow: hidden; }
    #container { position: absolute; top: 0; left: 0; width: 100%; height: 100%; }
  </style>
  <script src="visioone.umd.cjs"></script>
</head>
<body>
  <div id="container"></div>
  <script>
    var visioOne = VisioOne.createVisioOne();
    var container = document.getElementById('container');

    visioOne.loadVenue({ hash: 'YOUR_MAP_HASH' }, container)
      .then(function (venue) {
        return visioOne.createView(container, venue);
      })
      .catch(function (error) {
        visioOne.showError(error, container);
      });
  </script>
</body>
</html>
```

Remplacez `YOUR_MAP_HASH` par le hash de votre carte.

### API JS essentielle

| Appel | Rôle |
|---|---|
| `VisioOne.createVisioOne()` | Crée l'instance principale du SDK. |
| `visioOne.loadVenue({ hash, baseURL?, disableCache?, authorizationToken? }, container)` | Charge les données de la carte (`container` affiche un loader pendant le chargement). Retourne une `Promise<Venue>`. |
| `visioOne.createView(container, venue, options?)` | Crée le rendu 3D interactif de la carte dans `container`. Retourne une `Promise<View>`. |
| `visioOne.showError(error, container)` | Affiche une erreur dans l'UI du SDK (sinon elle part en console). |
| `visioOne.unloadVenue(venue)` / `visioOne.destroyView(view)` | Libère les ressources (utile en cas de changement de carte ou de fermeture d'écran). |

`options` de `createView` permet notamment `zoomSpeed`, `cameraProjection` (`perspective`/`orthographic`), `zenithalMode`, `lockPitch`.

L'ensemble de l'API (POI, navigation, markers, événements…) est documenté sur [my.visioglobe.com/docs](https://my.visioglobe.com/docs/) et dans les fichiers `.d.ts` livrés avec le package npm.

## 4. Déclarer les ressources dans le projet Xcode

Le dossier `WebContent` doit être ajouté comme **référence de dossier** (icône bleue) et non comme groupe, afin que sa hiérarchie soit préservée dans le bundle applicatif (sinon les fichiers sont mis à plat et `map.html` ne retrouvera pas `visioone.umd.cjs` à côté de lui, sauf à ajuster les chemins).

**Dans Xcode :** glissez le dossier `WebContent` dans le navigateur de projet et sélectionnez **"Create folder references"** (pas "Create groups").

**Avec [XcodeGen](https://github.com/yonaskolb/XcodeGen)** (`project.yml`) :

```yaml
targets:
  MonApp:
    type: application
    platform: iOS
    sources:
      - path: MonApp
        excludes:
          - "WebContent/**"
      - path: MonApp/WebContent
        type: folder
        buildPhase: resources
```

## 5. Le wrapper SwiftUI / WKWebView

```swift
import SwiftUI
import WebKit

struct MapWebView: UIViewRepresentable {
    func makeUIView(context: Context) -> WKWebView {
        let webView = WKWebView(frame: .zero)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.bounces = false
        webView.navigationDelegate = context.coordinator

        if let url = Bundle.main.url(forResource: "map", withExtension: "html", subdirectory: "WebContent") {
            webView.loadFileURL(url, allowingReadAccessTo: url.deletingLastPathComponent())
        }

        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    func makeCoordinator() -> Coordinator { Coordinator() }

    final class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("VisioOne map load failed: \(error.localizedDescription)")
        }
    }
}
```

```swift
import SwiftUI

struct ContentView: View {
    var body: some View {
        MapWebView()
            .ignoresSafeArea()
    }
}
```

`loadFileURL(_:allowingReadAccessTo:)` est indispensable : il autorise WebKit à lire, depuis un contexte `file://`, tous les fichiers du dossier passé en second argument (ici `WebContent/`), donc `visioone.umd.cjs` à côté de `map.html`.

## 6. Info.plist

Aucune entrée particulière n'est nécessaire :

- Le SDK charge les données de carte en **HTTPS** (`https://mapserver.visioglobe.com/` par défaut) : l'App Transport Security par défaut d'iOS l'autorise sans exception à déclarer.
- Aucune permission (localisation, caméra, micro…) n'est demandée pour un affichage de carte standard. Si vous activez des fonctionnalités qui y font appel (ex. géolocalisation de l'utilisateur), ajoutez alors la clé `NSLocationWhenInUseUsageDescription` correspondante.
- Si vous utilisez `GENERATE_INFOPLIST_FILE: YES` (Xcode moderne / XcodeGen), pensez à définir `CURRENT_PROJECT_VERSION` et `MARKETING_VERSION` dans les build settings : sans eux, `CFBundleVersion` est absent et l'installation sur simulateur/device échoue.

## 7. Build & test

```bash
xcodebuild -project MonApp.xcodeproj -scheme MonApp -sdk iphonesimulator \
  -destination 'generic/platform=iOS Simulator' build
```

Puis installation/lancement sur un simulateur démarré :

```bash
xcrun simctl install <UDID> path/to/MonApp.app
xcrun simctl launch <UDID> com.example.monapp
```

Une capture d'écran (`xcrun simctl io <UDID> screenshot out.png`) permet de vérifier visuellement le rendu de la carte.

## Aller plus loin

- **Communication native ↔ JS** : pour piloter la carte depuis Swift (ex. bouton natif qui centre la carte sur un POI), utilisez `webView.evaluateJavaScript(...)` pour appeler l'API JS, et un `WKScriptMessageHandler` pour faire remonter des événements JS (clic sur un POI, fin de navigation…) vers Swift.
- **Personnalisation de l'UI**, **gestion des POI**, **routage multimodal**, **markers personnalisés** : voir la documentation complète sur [my.visioglobe.com/docs](https://my.visioglobe.com/docs/) et la démo officielle.
- **Support** : [portail support Visioglobe](https://my.visioglobe.com/support).
