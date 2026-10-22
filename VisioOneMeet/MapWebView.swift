import SwiftUI
import WebKit

struct MapWebView: UIViewRepresentable {
    let bridge: VisioOneBridge
    /// Map hash to load (`Feature.mapHash`, values in `DemoMap.swift`).
    /// Appended as a `?vg_maphash=` query item on the `file://` URL passed
    /// to `loadFileURL`, read back on the JS side via
    /// `URLSearchParams(window.location.search)` (see `map.html`). `nil`
    /// only for the auth-token sample, which passes its hash through
    /// `protectedMap` instead.
    var mapHash: String?

    /// Optional `baseURL` to pass to `loadVenue`, same override mechanism as
    /// `mapHash` above but for the custom-base-url feature: appended as
    /// a second `?baseURL=` query item, read back in `map.html`. `nil` (the
    /// default) leaves the SDK's own built-in `baseURL` default in effect.
    /// See `docs/features/custom-base-url.md`.
    var baseURLOverride: String?

    /// Whether `map.html` should create the view with
    /// `createView(container, venue, { enableShadows: true })`, appended as
    /// an `?enableShadows=1` query item (same mechanism as the two overrides
    /// above). Only the custom-theme feature sets it: `view.setTheme()` has
    /// no visible effect without it, and shadows are expensive, so every
    /// other screen keeps the SDK default. See `docs/features/custom-theme.md`.
    var enableShadows = false

    /// `createView`'s `cameraProjection` option, appended as a
    /// `?cameraProjection=` query item (same mechanism as above). `nil` (the
    /// default) keeps the SDK default; only the camera-projection-toggle
    /// feature sets it. See `docs/features/camera-projection-toggle.md`.
    var cameraProjection: CameraProjection?

    /// When set, `map.html` loads this token-protected map via its
    /// `loadProtectedVenue()` instead of its default public map. Injected as
    /// a document-start user script (not a query item: a JWT doesn't belong
    /// in a URL). `nil` (the default) leaves every screen unchanged -- no
    /// demo screen sets it, it's the auth-token code sample's entry point.
    /// See `ProtectedMapSample.swift` and `docs/features/auth-token.md`.
    var protectedMap: ProtectedMapOptions?

    func makeUIView(context: Context) -> WKWebView {
        let contentController = WKUserContentController()
        contentController.add(WeakScriptMessageHandler(target: bridge), name: VisioOneBridge.messageHandlerName)
        if let script = protectedMap?.userScript {
            contentController.addUserScript(script)
        }

        let configuration = WKWebViewConfiguration()
        configuration.allowsInlineMediaPlayback = true
        configuration.userContentController = contentController

        let webView = WKWebView(frame: .zero, configuration: configuration)
        webView.isOpaque = false
        webView.backgroundColor = .black
        webView.scrollView.bounces = false
        webView.navigationDelegate = context.coordinator

        #if DEBUG
        if #available(iOS 16.4, *) {
            webView.isInspectable = true
        }
        #endif

        if let url = Bundle.main.url(forResource: "map", withExtension: "html", subdirectory: "WebContent") {
            let urlToLoad: URL
            if (mapHash != nil || baseURLOverride != nil || enableShadows || cameraProjection != nil),
               var components = URLComponents(url: url, resolvingAgainstBaseURL: false) {
                var queryItems: [URLQueryItem] = []
                if let mapHash {
                    queryItems.append(URLQueryItem(name: "vg_maphash", value: mapHash))
                }
                if let baseURLOverride {
                    queryItems.append(URLQueryItem(name: "baseURL", value: baseURLOverride))
                }
                if enableShadows {
                    queryItems.append(URLQueryItem(name: "enableShadows", value: "1"))
                }
                if let cameraProjection {
                    queryItems.append(URLQueryItem(name: "cameraProjection", value: cameraProjection.rawValue))
                }
                components.queryItems = queryItems
                urlToLoad = components.url ?? url
            } else {
                urlToLoad = url
            }
            // Read access must stay scoped to the original file's directory
            // (the query string isn't part of the path WebKit checks
            // against here) -- confirmed live against a real WKWebView
            // (loading this exact map.html + the vendored SDK bundle) that
            // appending `?vg_maphash=...` to this file:// URL still resolves
            // sibling resources (visioone.umd.cjs) fine, that
            // `window.location.search` on the JS side sees the query, and
            // that the overridden venue loads and returns real CustomData.
            // See docs/features/custom-data.md.
            webView.loadFileURL(urlToLoad, allowingReadAccessTo: url.deletingLastPathComponent())
        }

        bridge.webView = webView
        return webView
    }

    func updateUIView(_ uiView: WKWebView, context: Context) {}

    static func dismantleUIView(_ uiView: WKWebView, coordinator: Coordinator) {
        uiView.configuration.userContentController.removeScriptMessageHandler(forName: VisioOneBridge.messageHandlerName)
    }

    func makeCoordinator() -> Coordinator {
        Coordinator()
    }

    final class Coordinator: NSObject, WKNavigationDelegate {
        func webView(_ webView: WKWebView, didFail navigation: WKNavigation!, withError error: Error) {
            print("VisioOne map load failed: \(error.localizedDescription)")
        }

        func webView(_ webView: WKWebView, didFailProvisionalNavigation navigation: WKNavigation!, withError error: Error) {
            print("VisioOne map provisional load failed: \(error.localizedDescription)")
        }
    }
}
