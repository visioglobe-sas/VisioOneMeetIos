# VisioOneMeet (iOS natif)

Application iOS (Swift/SwiftUI) qui affiche une carte [VisioOne](https://www.npmjs.com/package/@visioglobe/visioone) plein écran dans une `WKWebView`. Le SDK VisioOne est un SDK **web** (JS/WebGL) : il n'y a pas de binaire Swift natif, l'app embarque le SDK JS et une page HTML hôte, et les affiche dans une WebView.

## Démarrage rapide

Prérequis : Xcode 15+ (testé avec Xcode 16.2), iOS 16+, [XcodeGen](https://github.com/yonaskolb/XcodeGen) (`brew install xcodegen`).

```bash
xcodegen generate       # régénère VisioOneMeet.xcodeproj à partir de project.yml
open VisioOneMeet.xcodeproj
```

Puis build/run depuis Xcode (⌘R), ou en ligne de commande :

```bash
xcodebuild -project VisioOneMeet.xcodeproj -scheme VisioOneMeet \
  -destination 'generic/platform=iOS Simulator' build
```

> `project.yml` régénère le projet à chaque changement de structure de fichiers (ajout/suppression de fichiers Swift, changement des sources `WebContent/`, etc.) — pensez à relancer `xcodegen generate` après ce type de changement, avant d'ouvrir Xcode.

## Structure

```
VisioOneMeet/
├── VisioOneMeetApp.swift    // entry point
├── ContentView.swift        // affiche MapWebView plein écran
├── MapWebView.swift         // wrapper WKWebView (UIViewRepresentable)
└── WebContent/              // page(s) HTML + SDK, chargées en file:// dans la WebView
    ├── map.html             // page "normale" : carte VisioOne via le SDK bundlé en UMD
    ├── diagnostic.html       // page de test/debug annexe pour la WebView
    └── visioone.umd.cjs     // SDK VisioOne, bundle UMD (~5 Mo), embarqué localement
```

## Documentation

- [`docs/INTEGRATION.md`](docs/INTEGRATION.md) — guide complet : intégrer le SDK VisioOne dans une app iOS native from scratch (récupération du SDK, structure du projet, page HTML hôte, déclaration des ressources Xcode/XcodeGen, wrapper WKWebView, Info.plist, build & test).
- [`docs/APP_SDK_COMMUNICATION.md`](docs/APP_SDK_COMMUNICATION.md) — communication bidirectionnelle Swift ↔ JS (appeler le SDK depuis du code natif, remonter les événements SDK — clic sur un POI, etc. — vers SwiftUI), pièges courants (retain cycle sur `WKScriptMessageHandler`, injection JS) et debug du bridge via Safari Web Inspector.
