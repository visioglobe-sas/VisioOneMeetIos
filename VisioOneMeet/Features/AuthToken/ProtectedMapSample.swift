import Foundation
import WebKit

// MARK: - auth-token code sample
//
// Ready-to-adapt sample for loading a map protected by an authorization
// token (JWT). Every value below is a FICTITIOUS PLACEHOLDER: this demo has
// no protected map to load, so replace them with your own before using the
// sample. The app's "Protected map (token)" screen only points here; it never
// calls this code. See docs/features/auth-token.md.
//
// Usage, in your own SwiftUI view:
//
//     MapWebView(bridge: bridge, protectedMap: ProtectedMapSample.loadOptions(token: jwt))
//
// then, before the token expires:
//
//     bridge.setAuthorizationToken(freshJwt)

/// What `loadProtectedVenue()` (`WebContent/features/auth-token.js`) needs:
/// the protected map hash, the protected map server, and the JWT. Injected
/// into the page before its own scripts run (see `MapWebView.swift`), so the
/// token never ends up in a URL.
struct ProtectedMapOptions {
    let mapHash: String
    let baseURL: String
    let authorizationToken: String
}

enum ProtectedMapSample {
    /// Your protected map's hash -- distinct from any public map hash.
    static let mapHash = "YOUR_PROTECTED_MAP_HASH"

    /// The protected map server. The standard `mapserver.visioglobe.com`
    /// does not enforce tokens.
    static let baseURL = "https://mapserver-auth.visioglobe.com/"

    /// The JWT must be issued by YOUR OWN backend (Visioglobe provides the
    /// signing secret and the claims to use) and fetched by the app at
    /// runtime. Never embed the signing secret in the app. Tokens are
    /// short-lived (1 hour at most): refresh with
    /// `VisioOneBridge.setAuthorizationToken(_:)` before expiry.
    static let placeholderToken = "YOUR_JWT_FROM_YOUR_BACKEND"

    static func loadOptions(token: String = placeholderToken) -> ProtectedMapOptions {
        ProtectedMapOptions(mapHash: mapHash, baseURL: baseURL, authorizationToken: token)
    }
}

extension VisioOneBridge {
    /// Message posted by `features/auth-token.js` when `loadVenue` rejects
    /// with the SDK's `UnauthorizedError`, handled in
    /// `userContentController(_:didReceive:)`.
    static let unauthorizedMessageType = "unauthorized"

    /// Token-refresh entry point: forwards a fresh JWT to the loaded venue
    /// via `venue.setAuthorizationToken()`, used by every subsequent map
    /// request (no reload needed). Call it before the current token expires.
    /// A failure is logged.
    func setAuthorizationToken(_ freshToken: String) {
        callReportingStatus("setAuthorizationToken", args: [freshToken])
    }
}

extension ProtectedMapOptions {
    /// Script injected at document start, defining the options the page
    /// reads to call `loadProtectedVenue()` instead of loading its default
    /// public map (see `MapCore.start()` in `WebContent/bridge/core.js`).
    var userScript: WKUserScript? {
        let options: [String: String] = [
            "vg_maphash": mapHash,
            "baseURL": baseURL,
            "authorizationToken": authorizationToken,
        ]
        guard let data = try? JSONSerialization.data(withJSONObject: options),
              let json = String(data: data, encoding: .utf8) else { return nil }
        return WKUserScript(
            source: "window.VISIOONE_PROTECTED_MAP = \(json);",
            injectionTime: .atDocumentStart,
            forMainFrameOnly: true
        )
    }
}
